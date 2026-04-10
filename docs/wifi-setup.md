# WiFi Support in WinRE

---

## Why WinRE and Not Standard WinPE?

Standard Windows PE (WinPE) does not include the wireless networking stack. It has no built-in support for WiFi - only wired Ethernet.

**Windows Recovery Environment (WinRE)** is the recovery partition environment that ships with every Windows installation. It does include the wireless networking stack, making WiFi connectivity possible in the boot environment.

This is why `Build-WinREBootImage.ps1` uses `-WinRE` when creating the template:

```powershell
New-OSDCloudTemplate -WinRE -Name "WinRE-WiFi"
```

Without `-WinRE`, the boot image would support Ethernet only - no WiFi, no deployment on machines without a wired connection.

---

## Build Machine OS Requirement

The WinRE source files come from the **build machine's own Windows Recovery Environment**. A **Windows 11 24H2** build machine is required to produce a Windows 11 24H2 WinRE boot image.

Target hardware must support TPM 2.0 and Secure Boot to boot a Windows 11 WinRE image.

---

## Intel WiFi Driver Injection

Even with WinRE's wireless stack, the boot image needs WiFi adapter drivers to connect to a network. Most modern Intel WiFi adapters are not included by default.

The `-CloudDriver WiFi` parameter in `Edit-OSDCloudWinPE` injects the Intel WiFi driver pack directly into the WinRE image:

```powershell
Edit-OSDCloudWinPE -WorkspacePath $WorkspacePath `
                   -StartURL $DeployURL `
                   -CloudDriver WiFi
```

This covers the vast majority of Intel WiFi adapters found in modern laptops and desktops.

For hardware using non-Intel WiFi adapters (e.g. some Realtek, MediaTek), use `BootImage/Edit-WinREDrivers.ps1` to inject additional drivers.

---

## WiFi Credential Prompt at Boot

When the USB boots, `Startnet.cmd` runs a WiFi setup step before attempting to fetch the deployment script. This step:

1. Checks if the machine is already connected (Ethernet or WiFi) — if so, skips the prompt
2. If not connected, prompts the operator for the local WiFi **SSID** and **password**
3. Connects using WPA2-Personal (or open if no password is entered)
4. Continues to fetch and run the deployment script

The operator will see:

```
[WiFi] No network detected. Enter WiFi credentials for this location.

  SSID: <type SSID here>
  Password (leave blank for open network): ****
[WiFi] Connecting...
[WiFi] Connected to: <SSID>
```

The password is masked during entry. If the connection fails, the deployment script has a second network check that will allow the operator to retry.

---

## How the OSDCloud Module Gets Into WinRE

When WinRE boots and runs `Startnet.cmd`, the OSDCloud module is not pre-installed in the boot image. Instead, OSDCloud bootstraps itself:

1. WinRE boots
2. WiFi prompt runs — operator connects to local WiFi
3. `Startnet.cmd` fetches `Deploy-Windows11.ps1` from Azure Blob Storage
4. `Deploy-Windows11.ps1` loads the OSDCloud module from PowerShell Gallery and starts the deployment

**WiFi must be connected before the deployment script runs.** If the module download fails (no connectivity), the deployment will not start. This is expected - the deployment is entirely cloud-based and requires internet access throughout.

---

## Troubleshooting WiFi Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| WiFi prompt does not appear | wpeinit hasn't finished loading drivers | Wait a few seconds after boot |
| Can connect to network but can't download | DNS or proxy issue in WinRE | Try a different network |
| Module download fails | PSGallery unreachable | Check connectivity from WinRE shell |
| Known adapter not detected | Driver not in CloudDriver set | Use `Edit-WinREDrivers.ps1` with `-DriverPath` |

See also: [troubleshooting.md](troubleshooting.md)
