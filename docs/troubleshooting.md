# Troubleshooting

Common issues and fixes for the OSDCloud deployment environment.

---

## Boot Issues

### USB does not boot

**Symptom:** Machine powers on but ignores the USB or shows an error.

**Fixes:**
- Disable **Secure Boot** in BIOS/UEFI settings
- Check that USB is set as first boot device or use the one-time boot menu (F12, F11, etc.)
- If Rufus warned about ISOHybrid during creation, ensure you selected **Write in ISO Image mode** (not DD mode)
- Try a different USB port (USB 3.0 ports occasionally have compatibility issues in WinPE - try a USB 2.0 port)

---

### WinRE won't boot on older hardware

**Symptom:** USB boots but shows a compatibility error, hangs on logo, or immediately reboots.

**Cause:** Windows 11 24H2 WinRE requires TPM 2.0 and Secure Boot, which older hardware may not support.

**Fix:** For older hardware without TPM 2.0, rebuild the image on a **Windows 10 22H2** build machine (physical or Hyper-V VM).

See [prerequisites.md](prerequisites.md) and [wifi-setup.md](wifi-setup.md).

---

## WiFi Issues

### WiFi prompt does not appear / machine has no network

**Cause:** Intel WiFi driver was not injected during the build.

**Fix:** Verify `Build-WinREBootImage.ps1` used `-CloudDriver WiFi`. If not, rebuild.

For non-Intel adapters: use `BootImage/Edit-WinREDrivers.ps1` with `-DriverPath` pointing to your adapter's driver folder.

---

### WiFi connects but OSDCloud module fails to download

**Symptom:** Network connects but the deployment stalls with a module error.

**Causes and fixes:**
- PSGallery is temporarily unavailable - wait and retry
- Network has a web proxy or firewall blocking PowerShell Gallery (`powershellgallery.com`, `oneget.org`)
- DNS not resolving - check with `nslookup powershellgallery.com` in the WinRE shell

---

## Script Execution Issues

### `-StartURL` script is not executing

**Symptom:** WinRE boots but nothing happens after WiFi connects, or you see a download error.

**Causes and fixes:**
- The StartURL baked into the boot image is wrong. Verify `Build-WinREBootImage.ps1` stamps the correct URL:
  ```
  https://codostpublicassets.blob.core.windows.net/osdcloud/Deploy-Windows11.ps1
  ```
  If not, update `$DeployURL` in `Build-WinREBootImage.ps1` and rebuild.
- The blob is not publicly accessible. Confirm the `osdcloud` container in the `codostpublicassets` storage account has **Blob (anonymous read)** access.
- The file has not been uploaded to blob storage yet. Upload `Deploy-Windows11.ps1` manually via Azure Portal or CLI.

---

### `#Requires -RunAsAdministrator` error in WinRE

**Symptom:** Deploy-Windows11.ps1 throws an error about administrator privileges.

**Cause:** `Deploy-Windows11.ps1` should not have `#Requires -RunAsAdministrator` - WinRE runs as SYSTEM, and this directive causes errors.

**Fix:** Remove the `#Requires` line from `Deploy-Windows11.ps1`. See the note in the script header.

---

## ISO Download Issues

### Azure blob returns 404 or access denied

**Symptoms:** ISO URL returns a 404 or access denied error.

**Fixes:**
- Verify the blob container access is set to **Blob (anonymous read)** - not private
- Verify the exact URL: `https://codostpublicassets.blob.core.windows.net/osdcloud/CoduxOSDCloud.iso`
  - Container name: `osdcloud`
  - Blob name: `CoduxOSDCloud.iso` (case-sensitive)
- Confirm the ISO was uploaded successfully in the Azure Portal

---

## Deployment Issues

### Windows 11 fails to download

**Symptom:** OSDCloud starts but fails downloading the OS image from Microsoft.

**Fixes:**
- Check internet speed and stability - a dropped connection mid-download causes failure
- Resync time: `w32tm /resync /force` (WinRE clock drift can cause TLS errors)
- Retry - Microsoft Update servers occasionally throttle requests

---

### Driver issues after Windows installs

**Symptom:** Windows installs successfully but has missing drivers (WiFi, display, etc.).

**Fix:** Run `BootImage/Apply-WinOSDrivers.ps1` post-deployment to apply OOB drivers, or check that the correct driver pack is being pulled during deployment.

---

## ADK Issues

### ADK version mismatch

**Symptom:** `New-OSDCloudTemplate` emits `WARNING: Add-WindowsPackage failed. Error code = 0x800f081e` for WinPE language CABs.

**Cause:** The ADK version doesn't match the WinRE image on the build machine.

**Fix:** Install the **ADK for Windows 11, version 24H2** (build 26100).

1. Uninstall the existing ADK and WinPE add-on from Apps & Features
2. Go to the ADK download page and download the latest ADK (Windows 11, version 24H2):
   `https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install`
   Download and install both **adksetup.exe** (Deployment Tools) and **adkwinpesetup.exe** (Windows Preinstallation Environment)
3. Run `Setup/Verify-Environment.ps1` — ADK Version Match should show PASS
