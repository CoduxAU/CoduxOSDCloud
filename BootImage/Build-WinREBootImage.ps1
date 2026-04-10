#Requires -RunAsAdministrator
#Requires -Version 7.0

<#
.SYNOPSIS
    Builds a WinRE-based OSDCloud boot image and stamps the GitHub deployment URL into Startnet.cmd.

.DESCRIPTION
    Creates an OSDCloud workspace from a WinRE template, injects Intel WiFi drivers, stamps
    the live deployment script URL into the boot image, and injects WiFi auto-connect logic
    so pre-created WiFi profiles on the boot media are loaded automatically at startup.

    Run this once - the USB never needs to be rebuilt when deployment config changes.
    To change what gets deployed, edit Deployment/Deploy-Windows11.ps1 and push to main.

    IMPORTANT: This script is configured for a Windows 11 24H2 build machine.
    Windows 11 24H2 WinRE requires TPM 2.0 and Secure Boot on target hardware.
    For older hardware without TPM 2.0, use a Windows 10 22H2 build machine instead.

.PARAMETER WorkspacePath
    Path where the OSDCloud workspace will be created. Default: C:\OSDCloud\WinRE-WiFi

.PARAMETER TemplateName
    Name for the OSDCloud template. Default: WinRE-WiFi

.PARAMETER Language
    Language code for the WinRE environment. Default: en-us

.PARAMETER SetInputLocale
    Input locale code. Default: 0c09:00000409 (Australian English)

.EXAMPLE
    .\BootImage\Build-WinREBootImage.ps1

.EXAMPLE
    .\BootImage\Build-WinREBootImage.ps1 -WorkspacePath 'C:\OSDCloud\MyBuild' -Language 'en-us'

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Codux/CoduxOSDCloud
    Requires: OSDCloud module, Windows ADK for Windows 11 24H2, Windows 11 24H2 build machine
    Deploy URL: https://codostpublicassets.blob.core.windows.net/osdcloud/Deploy-Windows11.ps1
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$WorkspacePath = 'C:\OSDCloud\WinRE-WiFi',

    [Parameter()]
    [string]$TemplateName = 'WinRE-WiFi',

    [Parameter()]
    [string]$Language = 'en-us',

    [Parameter()]
    [string]$SetInputLocale = '0c09:00000409'
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Status {
    param([string]$Message, [string]$Status = 'INFO')
    $color = switch ($Status) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'INFO'  { 'Cyan' }
        default { 'White' }
    }
    Write-Host "[$Status] $Message" -ForegroundColor $color
}

$logDir = "$env:ProgramData\OSDCloud\Logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "Build-WinREBootImage_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Verbose $entry
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  OSDCloud WinRE Boot Image Builder' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

# OS check - Windows 11 24H2 (build 26100) is required for 24H2 WinRE
$osInfo    = Get-CimInstance Win32_OperatingSystem
$osCaption = $osInfo.Caption
$osBuild   = ($osInfo.Version -split '\.')[2]
$isWin11_24H2 = ($osCaption -match 'Windows 11') -and ($osBuild -eq '26100')

Write-Status "Build machine OS: $osCaption (build $osBuild)" -Status 'INFO'
Write-Log "Build machine OS: $osCaption (build $osBuild)"

if (-not $isWin11_24H2) {
    Write-Host ''
    Write-Status '!! WARNING: Build machine is not Windows 11 24H2 !!' -Status 'WARN'
    Write-Status 'The WinRE image will be sourced from this OS, not Windows 11 24H2.' -Status 'WARN'
    Write-Status 'Target hardware requires TPM 2.0 + Secure Boot for Win11 24H2 WinRE.' -Status 'WARN'
    Write-Status 'For older hardware (no TPM), use a Windows 10 22H2 build machine.' -Status 'WARN'
    Write-Host ''
    $continue = Read-Host 'Continue anyway? [Y/N]'
    if ($continue -notmatch '^[Yy]') {
        Write-Status 'Aborted.' -Status 'WARN'
        exit 0
    }
    Write-Log "User acknowledged non-24H2 build machine ($osCaption build $osBuild)"
}

# Prerequisites check
Write-Status 'Verifying prerequisites...' -Status 'INFO'
$verifyScript = Join-Path $PSScriptRoot '..\Setup\Verify-Environment.ps1'
if (Test-Path $verifyScript) {
    try {
        & $verifyScript
        if ($LASTEXITCODE -ne 0) {
            Write-Status 'Prerequisites check failed. Run Setup\Install-Prerequisites.ps1 first.' -Status 'ERROR'
            exit 1
        }
    } catch {
        Write-Status "Could not run Verify-Environment.ps1: $_" -Status 'WARN'
        Write-Log "WARN: Verify-Environment.ps1 failed: $_"
    }
} else {
    Write-Status 'Verify-Environment.ps1 not found - skipping prereq check.' -Status 'WARN'
}

# OSDCloud module
try {
    Import-Module OSDCloud -Force -ErrorAction Stop
    Write-Status "OSDCloud module loaded: v$((Get-Module OSDCloud).Version)" -Status 'OK'
    Write-Log "OSDCloud module: v$((Get-Module OSDCloud).Version)"
} catch {
    Write-Status "OSDCloud module not found: $_" -Status 'ERROR'
    exit 1
}

# ---------------------------------------------------------------------------
# The deployment URL stamped into Startnet.cmd
# This is the ONLY value baked into the USB. Changing the script at this URL
# changes what all future deployments do - no USB rebuild required.
# ---------------------------------------------------------------------------
$DeployURL = 'https://codostpublicassets.blob.core.windows.net/osdcloud/Deploy-Windows11.ps1'

Write-Host ''
Write-Status "Deploy URL: $DeployURL" -Status 'INFO'
Write-Host ''

# ---------------------------------------------------------------------------
# Pre-Step - Dismount any stale WIM mounts from previous interrupted builds
# ---------------------------------------------------------------------------
Write-Status 'Checking for stale WIM mounts...' -Status 'INFO'
$staleMounts = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue
if ($staleMounts) {
    Write-Status "Found $($staleMounts.Count) stale mount(s) - dismounting..." -Status 'WARN'
    foreach ($mount in $staleMounts) {
        try {
            Dismount-WindowsImage -Path $mount.MountPath -Discard -ErrorAction Stop
            Write-Status "Dismounted: $($mount.MountPath)" -Status 'OK'
            Write-Log "Dismounted stale WIM: $($mount.MountPath)"
        } catch {
            Write-Status "Could not dismount $($mount.MountPath): $_" -Status 'WARN'
            Write-Log "WARN dismounting stale WIM: $_"
        }
    }
    Clear-WindowsCorruptMountPoint -ErrorAction SilentlyContinue
    Write-Status 'Stale mounts cleared.' -Status 'OK'
} else {
    Write-Status 'No stale mounts found.' -Status 'INFO'
}

# ---------------------------------------------------------------------------
# Steps 1-3 run under Windows PowerShell 5.1
# New-OSDCloudTemplate, New-OSDCloudWorkspace, and Edit-OSDCloudWinPE all
# use DISM COM components that fail under PowerShell 7 ("Class not registered").
# ---------------------------------------------------------------------------
$ps5 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path $ps5)) {
    Write-Status 'Windows PowerShell 5.1 not found - cannot continue.' -Status 'ERROR'
    exit 1
}

$dismScript = @"
# Add PS7 module path so PS5.1 can find modules installed via pwsh
`$ps7ModulePath = 'C:\Program Files\PowerShell\Modules'
if ((Test-Path `$ps7ModulePath) -and (`$env:PSModulePath -notlike "*`$ps7ModulePath*")) {
    `$env:PSModulePath = `$ps7ModulePath + ';' + `$env:PSModulePath
}

# Pre-install NuGet provider so module imports never prompt interactively.
# -ForceBootstrap on Install-PackageProvider suppresses the interactive prompt entirely.
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers -ForceBootstrap | Out-Null

Import-Module OSDCloud -Force -ErrorAction Stop

# Step 1 - Create OSDCloud Template (WinRE)
Write-Host '[INFO] Creating OSDCloud template from WinRE...' -ForegroundColor Cyan
New-OSDCloudTemplate -WinRE -Name '$TemplateName' -Verbose
if (`$LASTEXITCODE -and `$LASTEXITCODE -ne 0) { exit 1 }

# Step 2 - Create OSDCloud Workspace
Write-Host '[INFO] Creating workspace at: $WorkspacePath' -ForegroundColor Cyan
New-OSDCloudWorkspace -WorkspacePath '$WorkspacePath' -Verbose
if (`$LASTEXITCODE -and `$LASTEXITCODE -ne 0) { exit 2 }

# Step 3 - Inject WiFi drivers and stamp deploy URL
Write-Host '[INFO] Injecting WiFi drivers and stamping deployment URL...' -ForegroundColor Cyan
Edit-OSDCloudWinPE -WorkspacePath '$WorkspacePath' -StartURL '$DeployURL' -CloudDriver @('WiFi','IntelNet','Dell','HP','LenovoDock','Surface') -Verbose
if (`$LASTEXITCODE -and `$LASTEXITCODE -ne 0) { exit 3 }
"@

Write-Status 'Running DISM operations under Windows PowerShell 5.1...' -Status 'INFO'
Write-Log 'Launching PS5.1 for DISM steps'

& $ps5 -ExecutionPolicy Bypass -Command $dismScript

switch ($LASTEXITCODE) {
    0 {
        Write-Status 'Template created, workspace built, and deployment URL stamped.' -Status 'OK'
        Write-Log 'PS5.1 DISM steps completed successfully'
    }
    1 {
        Write-Status 'Failed to create OSDCloud template (Step 1).' -Status 'ERROR'
        Write-Log 'ERROR: Step 1 failed in PS5.1'
        exit 1
    }
    2 {
        Write-Status 'Failed to create OSDCloud workspace (Step 2).' -Status 'ERROR'
        Write-Log 'ERROR: Step 2 failed in PS5.1'
        exit 1
    }
    3 {
        Write-Status 'Failed to configure WinPE - WiFi drivers or deploy URL (Step 3).' -Status 'ERROR'
        Write-Log 'ERROR: Step 3 failed in PS5.1'
        exit 1
    }
    default {
        Write-Status "Unexpected exit code from PS5.1: $LASTEXITCODE" -Status 'ERROR'
        Write-Log "ERROR: Unexpected PS5.1 exit code: $LASTEXITCODE"
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Step 4 - Inject WiFi prompt into Startnet.cmd inside boot.wim
#
# At boot, before the deploy script can be fetched from Azure Blob Storage,
# the machine needs a network connection. This injects a PS prompt into
# Startnet.cmd that runs after wpeinit (so WiFi drivers are loaded) and asks
# the operator for SSID and password if no connection is already present.
# Skips if Ethernet or WiFi is already connected.
# ---------------------------------------------------------------------------
Write-Host ''
Write-Status 'Step 4: Injecting WiFi auto-connect into boot.wim...' -Status 'INFO'

$bootWimPath = Join-Path $WorkspacePath 'Media\sources\boot.wim'
$wimMountDir = Join-Path $env:TEMP 'OSDCloud_WimMount'

if (-not (Test-Path $bootWimPath)) {
    Write-Status "boot.wim not found at $bootWimPath - skipping WiFi inject." -Status 'WARN'
    Write-Log "WARN: boot.wim not found: $bootWimPath"
} else {
    # Clean up any stale mount at this path
    if (Test-Path $wimMountDir) {
        Write-Status 'Cleaning up stale WIM mount directory...' -Status 'WARN'
        & dism.exe /Unmount-Wim /MountDir:"$wimMountDir" /discard 2>$null | Out-Null
        Remove-Item $wimMountDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $wimMountDir -Force | Out-Null

    Write-Status 'Mounting boot.wim (index 1)...' -Status 'INFO'
    & dism.exe /Mount-Wim /WimFile:"$bootWimPath" /index:1 /MountDir:"$wimMountDir" | Out-Null

    if ($LASTEXITCODE -eq 0) {
        $startnetInsideWim = Join-Path $wimMountDir 'Windows\System32\Startnet.cmd'

        if (Test-Path $startnetInsideWim) {
            $existingStartnet = Get-Content $startnetInsideWim -Raw

            # Build WiFi prompt script as Base64-encoded command to avoid CMD escaping.
            # Prompts the operator for SSID and password if no connection is detected.
            # Supports WPA2-Personal (password entered) or open networks (blank password).
            # Skips entirely if already connected via Ethernet or WiFi.
            $wifiScript = @'
$connected = $false
try {
    if ((netsh wlan show interfaces 2>$null) -join ' ' -match 'State\s+:\s+connected') { $connected = $true }
} catch {}
if (-not $connected) {
    try {
        if ((ipconfig 2>$null) -join ' ' -match 'IPv4 Address.+:\s+(?!169\.254)\d') { $connected = $true }
    } catch {}
}

if ($connected) {
    Write-Host '[WiFi] Network already connected.' -ForegroundColor Green
} else {
    Write-Host ''
    Write-Host '[WiFi] No network detected. Enter WiFi credentials for this location.' -ForegroundColor Cyan
    Write-Host ''
    $ssid = Read-Host '  SSID'
    if ($ssid) {
        $passSecure = Read-Host '  Password (leave blank for open network)' -AsSecureString
        $pass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($passSecure))

        if ($pass) {
            $profileXml = '<?xml version="1.0"?><WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1"><name>' + $ssid + '</name><SSIDConfig><SSID><name>' + $ssid + '</name></SSID></SSIDConfig><connectionType>ESS</connectionType><connectionMode>auto</connectionMode><MSM><security><authEncryption><authentication>WPA2PSK</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption><sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>' + $pass + '</keyMaterial></sharedKey></security></MSM></WLANProfile>'
        } else {
            $profileXml = '<?xml version="1.0"?><WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1"><name>' + $ssid + '</name><SSIDConfig><SSID><name>' + $ssid + '</name></SSID></SSIDConfig><connectionType>ESS</connectionType><connectionMode>auto</connectionMode><MSM><security><authEncryption><authentication>open</authentication><encryption>none</encryption><useOneX>false</useOneX></authEncryption></security></MSM></WLANProfile>'
        }

        $tmpXml = Join-Path $env:TEMP 'WinREWiFi.xml'
        [System.IO.File]::WriteAllText($tmpXml, $profileXml)
        netsh wlan add profile filename="$tmpXml" | Out-Null
        netsh wlan connect name="$ssid" | Out-Null
        Write-Host '[WiFi] Connecting...' -ForegroundColor Cyan
        Start-Sleep -Seconds 10
        Remove-Item $tmpXml -Force -ErrorAction SilentlyContinue

        if ((netsh wlan show interfaces 2>$null) -join ' ' -match 'State\s+:\s+connected') {
            Write-Host "[WiFi] Connected to: $ssid" -ForegroundColor Green
        } else {
            Write-Host '[WiFi] Connection failed. Check credentials and try again.' -ForegroundColor Yellow
        }
    }
}
'@
            $encodedBytes   = [System.Text.Encoding]::Unicode.GetBytes($wifiScript)
            $encodedCommand = [Convert]::ToBase64String($encodedBytes)
            $wifiCmdLine    = "PowerShell -NoLogo -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"

            # Insert after the wpeinit line so WiFi drivers are loaded first.
            # If wpeinit is not found, prepend before all other commands.
            $lines = $existingStartnet -split '\r?\n'
            $wpeinitIdx = -1
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i].Trim() -imatch '^wpeinit\b') { $wpeinitIdx = $i; break }
            }

            if ($wpeinitIdx -ge 0) {
                $before     = ($lines[0..$wpeinitIdx]) -join "`r`n"
                $afterLines = if ($wpeinitIdx + 1 -lt $lines.Count) { $lines[($wpeinitIdx + 1)..($lines.Count - 1)] } else { @() }
                $after      = $afterLines -join "`r`n"
                $newContent = $before + "`r`n" + $wifiCmdLine + "`r`n" + $after
            } else {
                $newContent = $wifiCmdLine + "`r`n" + $existingStartnet
            }

            [System.IO.File]::WriteAllText($startnetInsideWim, $newContent, [System.Text.Encoding]::ASCII)
            Write-Status 'WiFi auto-connect injected into Startnet.cmd.' -Status 'OK'
            Write-Log 'WiFi auto-connect injected into Startnet.cmd inside boot.wim'

            # Also update the loose reference copy if it exists (used by Test-OSDEnvironment)
            $looseStartnet = Join-Path $WorkspacePath 'Media\Boot\x64\Startnet.cmd'
            if (Test-Path $looseStartnet) {
                [System.IO.File]::WriteAllText($looseStartnet, $newContent, [System.Text.Encoding]::ASCII)
                Write-Log 'Updated loose Startnet.cmd reference copy'
            }
        } else {
            Write-Status 'Startnet.cmd not found inside mounted boot.wim - skipping inject.' -Status 'WARN'
            Write-Log 'WARN: Startnet.cmd not found in WIM at Windows\System32\Startnet.cmd'
        }

        Write-Status 'Committing and unmounting boot.wim...' -Status 'INFO'
        & dism.exe /Unmount-Wim /MountDir:"$wimMountDir" /commit | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Status 'boot.wim committed successfully.' -Status 'OK'
            Write-Log 'boot.wim unmounted and committed'
        } else {
            Write-Status "DISM unmount returned exit code $LASTEXITCODE - WIM may need manual cleanup." -Status 'WARN'
            Write-Log "WARN: DISM unmount exit code: $LASTEXITCODE"
        }
    } else {
        Write-Status "Could not mount boot.wim (DISM exit $LASTEXITCODE) - WiFi auto-connect not injected." -Status 'WARN'
        Write-Log "WARN: DISM mount failed with exit code $LASTEXITCODE"
    }

    Remove-Item $wimMountDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host '  Boot Image Build Complete' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ''
Write-Status "Workspace:    $WorkspacePath" -Status 'INFO'
Write-Status "Deploy URL:   $DeployURL" -Status 'INFO'
Write-Status "Build OS:     $osCaption (build $osBuild)" -Status 'INFO'
Write-Status "Log:          $logFile" -Status 'INFO'
Write-Host ''
Write-Status 'Next steps:' -Status 'INFO'
Write-Host '  1. Run BootImage\New-OSDCloudISO.ps1 to generate the ISO' -ForegroundColor White
Write-Host '  2. Upload the ISO to Azure Blob Storage' -ForegroundColor White
Write-Host '  3. Update VERSION and CHANGELOG.md, then push' -ForegroundColor White
Write-Host ''
Write-Status 'REMINDER: The ISO is now static. To change the deployment, edit' -Status 'WARN'
Write-Status "          Deployment\Deploy-Windows11.ps1 and upload to Azure Blob Storage." -Status 'WARN'
Write-Host ''

Write-Log 'Build-WinREBootImage.ps1 completed successfully'
