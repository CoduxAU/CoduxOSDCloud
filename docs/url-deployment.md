# URL-Based Deployment Architecture

---

## How It Works

The USB / ISO only needs to be built **once**. There is no deployment logic baked into it - only a URL.

When WinRE boots, `Startnet.cmd` runs a single command:

```
PowerShell -NoLogo -ExecutionPolicy Bypass -Command "& { Invoke-Expression (Invoke-RestMethod -Uri '<StartURL>') }"
```

The `StartURL` was stamped into the boot image during the build:

```powershell
Edit-OSDCloudWinPE -StartURL 'https://codostpublicassets.blob.core.windows.net/osdcloud/Deploy-Windows11.ps1'
```

**Every time the machine boots from USB, it fetches the latest version of `Deploy-Windows11.ps1` from Azure Blob Storage.** Uploading a new version of the file immediately changes what all future deployments do. The USB never changes.

---

## Publishing a Script Update

The GitHub repo is private. Scripts are published by manually uploading via the **Azure Portal**:

1. Go to [portal.azure.com](https://portal.azure.com)
2. Navigate to **Storage accounts → codostpublicassets → Containers → osdcloud**
3. Click **Upload**, select the updated script file, tick **Overwrite if files already exist**, click **Upload**

> Uploading overwrites the existing blob immediately. All subsequent USB boots will use the new version.

---

## Deployment Flow

```
USB boots
    │
    ▼
WinRE loads
    │
    ▼
Startnet.cmd: WiFi prompt (operator enters SSID + password if not already connected)
    │
    ▼
Startnet.cmd fetches Deploy-Windows11.ps1 from Azure Blob Storage
    │
    ▼
Deploy-Windows11.ps1 runs → Start-OSDCloud
    │
    ▼
Windows 11 downloads from Microsoft Update and installs
    │
    ▼
Machine reboots into Windows
```

---

## Switching Deployment Modes

Three deployment modes are available without rebuilding the USB:

| Mode | What to do |
|------|-----------|
| **Standard** (interactive) | `Deploy-Windows11.ps1` - prompts for disk wipe confirmation |
| **ZTI** (silent) | Edit `Deploy-Windows11.ps1` to pass `-ZTI` and upload to blob |
| **GUI** (operator selects OS) | Re-stamp USB with `Start-OSDCloudGUI.ps1` URL (requires one USB rebuild) |

### Switching to the GUI variant

Re-stamp the workspace and regenerate the ISO:

```powershell
$GUIURL = 'https://codostpublicassets.blob.core.windows.net/osdcloud/Start-OSDCloudGUI.ps1'
Edit-OSDCloudWinPE -StartURL $GUIURL -WorkspacePath 'C:\OSDCloud\WinRE-WiFi'
# Then: .\BootImage\New-OSDCloudISO.ps1
```

---

## Azure Blob URLs

| Asset | URL |
|-------|-----|
| Deploy script (default) | `https://codostpublicassets.blob.core.windows.net/osdcloud/Deploy-Windows11.ps1` |
| GUI script | `https://codostpublicassets.blob.core.windows.net/osdcloud/Start-OSDCloudGUI.ps1` |
| Boot ISO | `https://codostpublicassets.blob.core.windows.net/osdcloud/CoduxOSDCloud.iso` |

All blobs are in the `osdcloud` container of the `codostpublicassets` storage account with **Blob (anonymous read)** access.
