# ISO Hosting - Azure Blob Storage

---

## Architecture

The ISO is hosted directly on **Azure Blob Storage** (Codux public assets account). The URL is stable and never changes:

```
https://codostpublicassets.blob.core.windows.net/osdcloud/CoduxOSDCloud.iso
         │                                         │          │
         │                                         │          └── Blob filename (stable)
         │                                         └── Container name
         └── Codux public assets storage account
```

To publish a new version, upload the new ISO overwriting the existing blob. The URL stays the same.

---

## Releasing a New ISO Version

1. Build the new ISO:
   ```powershell
   .\BootImage\Build-WinREBootImage.ps1
   .\BootImage\New-OSDCloudISO.ps1
   ```
   Output: `C:\OSDCloud\ISO\CoduxOSDCloud.iso`

2. Test on real hardware before publishing.

3. Upload via the **Azure Portal**:
   - Go to [portal.azure.com](https://portal.azure.com)
   - Navigate to **Storage accounts → codostpublicassets → Containers → osdcloud**
   - Click **Upload**
   - Select `C:\OSDCloud\ISO\CoduxOSDCloud.iso`
   - Expand **Advanced** and set **Blob type** to `Block blob`
   - Tick **Overwrite if files already exist**
   - Click **Upload**

4. Update `VERSION` file, add entry to `CHANGELOG.md`, commit and push to `main`.

---

## URL Summary

| Purpose | URL |
|---------|-----|
| ISO download | `https://codostpublicassets.blob.core.windows.net/osdcloud/CoduxOSDCloud.iso` |
| GUI script | `https://codostpublicassets.blob.core.windows.net/osdcloud/Start-OSDCloudGUI.ps1` |
| Live deployment script | `https://codostpublicassets.blob.core.windows.net/osdcloud/Deploy-Windows11.ps1` |
