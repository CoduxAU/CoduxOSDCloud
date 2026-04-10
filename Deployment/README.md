# Deployment

Scripts that run **inside WinRE at boot time**. These are fetched from Azure Blob Storage at boot - upload an updated file to the blob location to change all future deployments. The USB never needs to be rebuilt.

> **Note:** The GitHub repo is private. Scripts are published by manually uploading to Azure Blob Storage.

## Scripts

| Script | Azure Blob URL (baked into USB) |
|--------|----------------------------------|
| `Deploy-Windows11.ps1` | `https://codostpublicassets.blob.core.windows.net/osdcloud/Deploy-Windows11.ps1` |
| `Start-OSDCloudGUI.ps1` | `https://codostpublicassets.blob.core.windows.net/osdcloud/Start-OSDCloudGUI.ps1` |

## Switching Modes (No USB Rebuild Required)

The USB is stamped with a single StartURL. To switch between standard, ZTI, and GUI modes without rebuilding the USB, you can modify `Deploy-Windows11.ps1` and upload it to blob storage.

To re-stamp the USB with a different URL (e.g. to switch to the GUI variant):

```powershell
Edit-OSDCloudWinPE -StartURL 'https://codostpublicassets.blob.core.windows.net/osdcloud/Start-OSDCloudGUI.ps1' `
                   -WorkspacePath "C:\OSDCloud\WinRE-WiFi"
```

Then regenerate the ISO and USB.

## ZTI (Zero Touch) Mode

Pass `-ZTI` to `Deploy-Windows11.ps1` to skip the disk-wipe confirmation prompt:

```
Deploy-Windows11.ps1 -ZTI
```

This is useful for fully automated deployments where no operator interaction is expected.

See [docs/url-deployment.md](../docs/url-deployment.md) for architecture details.
