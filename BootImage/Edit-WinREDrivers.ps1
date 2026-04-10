#Requires -RunAsAdministrator
#Requires -Version 7.0

<#
.SYNOPSIS
    Injects custom drivers from a local folder into an existing OSDCloud WinRE workspace.

.DESCRIPTION
    Use this script for hardware with drivers not covered by the standard CloudDriver packs
    (e.g. Realtek or MediaTek WiFi adapters, specialist storage controllers).

    All standard vendor CloudDrivers (Dell, HP, Lenovo, Surface, WiFi, Ethernet) are already
    injected by Build-WinREBootImage.ps1. This script is for custom local drivers only.

    Run this after Build-WinREBootImage.ps1 and before New-OSDCloudISO.ps1.

.PARAMETER DriverPath
    Path to a local folder containing INF/driver files to inject.

.PARAMETER WorkspacePath
    Path to the existing OSDCloud WinRE workspace. Default: C:\OSDCloud\WinRE-WiFi

.EXAMPLE
    .\BootImage\Edit-WinREDrivers.ps1 -DriverPath 'C:\Drivers\RealtekWiFi'

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Codux/CoduxOSDCloud
    Requires: OSDCloud module, existing WinRE workspace (run Build-WinREBootImage.ps1 first)
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$DriverPath,

    [Parameter()]
    [string]$WorkspacePath = 'C:\OSDCloud\WinRE-WiFi'
)

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
$logFile = Join-Path $logDir "Edit-WinREDrivers_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Verbose $entry
}

Write-Log 'Edit-WinREDrivers.ps1 started'

if (-not (Test-Path $WorkspacePath)) {
    Write-Status "Workspace not found: $WorkspacePath" -Status 'ERROR'
    Write-Status 'Run BootImage\Build-WinREBootImage.ps1 first.' -Status 'ERROR'
    exit 1
}

if (-not (Test-Path $DriverPath)) {
    Write-Status "DriverPath not found: $DriverPath" -Status 'ERROR'
    exit 1
}

try {
    Import-Module OSDCloud -Force -ErrorAction Stop
    Write-Status "OSDCloud module loaded: v$((Get-Module OSDCloud).Version)" -Status 'OK'
} catch {
    Write-Status "OSDCloud module not found: $_" -Status 'ERROR'
    exit 1
}

try {
    Write-Status "Injecting drivers from: $DriverPath" -Status 'INFO'
    Write-Log "DriverPath: $DriverPath"
    Edit-OSDCloudWinPE -WorkspacePath $WorkspacePath -DriverPath $DriverPath -Verbose
    Write-Status 'Driver injection complete.' -Status 'OK'
    Write-Log 'Driver injection completed'
} catch {
    Write-Status "Driver injection failed: $_" -Status 'ERROR'
    Write-Log "ERROR: $_"
    exit 1
}

Write-Status "Log saved to: $logFile" -Status 'INFO'
Write-Log 'Edit-WinREDrivers.ps1 completed'
