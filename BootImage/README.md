# BootImage

Scripts for building the WinRE boot image and generating the ISO.

> Run these scripts on a **Windows 11 24H2** build machine.

## Scripts

| Script | Purpose |
|--------|---------|
| `Build-WinREBootImage.ps1` | Builds the WinRE boot image and stamps the deployment URL into Startnet.cmd |
| `Edit-WinREDrivers.ps1` | Injects custom local drivers into an existing WinRE workspace |
| `Apply-WinOSDrivers.ps1` | Applies OOB drivers to the deployed Windows OS after installation |
| `New-OSDCloudISO.ps1` | Generates a bootable ISO from the active workspace |

## Build Order

1. `Setup/Install-Prerequisites.ps1` - once, on a fresh build machine
2. `Build-WinREBootImage.ps1` - builds the workspace and stamps the URL
3. `Edit-WinREDrivers.ps1` - optional, for custom driver injection only
4. `New-OSDCloudISO.ps1` - generates the ISO for upload to Azure Blob Storage

Use **Rufus** to write the ISO to a USB drive. See the root [README](../README.md) for instructions.

## Key Fact

The ISO only needs to be built **once**. The boot image fetches the deployment script live from Azure Blob Storage at boot time. To change what gets deployed, edit `Deployment/Deploy-Windows11.ps1` and upload it to the blob - no rebuild needed.

See [docs/url-deployment.md](../docs/url-deployment.md) for how this works.
