# Deployment Guide - End-to-End Setup

This guide walks the **repo owner** through the full setup process from a fresh machine to a working community deployment system.

---

## Prerequisites

Before starting:
- A **Windows 11 24H2 build machine** (physical or Hyper-V VM)
- Internet access
- An Azure subscription (Codux blob storage already configured)

See [prerequisites.md](prerequisites.md) for the full list.

---

## Step 1 - Prepare the Build Machine

Run on the Windows 11 24H2 build machine as Administrator in PowerShell 7:

```powershell
# Clone the repo
git clone https://github.com/Codux/CoduxOSDCloud.git
cd CoduxOSDCloud

# Install all prerequisites
.\Setup\Install-Prerequisites.ps1

# Verify everything is ready
.\Setup\Verify-Environment.ps1
```

All checks should pass before continuing.

---

## Step 2 - Configure the Deployment Script

Open `Deployment/Deploy-Windows11.ps1` and confirm the OS options match your environment:

```powershell
$OSVersion    = 'Windows 11'
$OSReleaseID  = '25H2'
$OSEdition    = 'Pro'       # Pro | Education | Enterprise
$OSLanguage   = 'en-au'
$OSActivation = 'Retail'    # Retail | Volume
```

Confirm each value is correct before continuing. No changes are needed if the defaults match your target deployment.

---

## Step 3 - Build the WinRE Boot Image

```powershell
.\BootImage\Build-WinREBootImage.ps1
```

This will:
- Warn if the build machine is not Windows 11 24H2
- Create the OSDCloud workspace at `C:\OSDCloud\WinRE-WiFi`
- Inject Intel WiFi drivers
- Stamp the GitHub deployment URL into Startnet.cmd
- Inject WiFi auto-connect logic into boot.wim

This step takes 10–20 minutes. **Run it only once** - it does not need to be repeated when deployment config changes.

---

## Step 4 - Generate the ISO

```powershell
.\BootImage\New-OSDCloudISO.ps1
```

This produces `C:\OSDCloud\ISO\CoduxOSDCloud.iso` and `CoduxOSDCloud-NoPrompt.iso`.

Note the SHA256 hash output - keep it for verification.

---

## Step 5 - Upload ISO to Azure Blob Storage

Upload `CoduxOSDCloud.iso` to the Codux blob container:

```
https://codostpublicassets.blob.core.windows.net/osdcloud/CoduxOSDCloud.iso
```

Verify the download URL is accessible after uploading.

---

## Step 6 - Update VERSION and CHANGELOG

Update `VERSION` to the current release number if needed, and add an entry to `CHANGELOG.md` under ISO Release History.

---

## Step 7 - Verify End-to-End

1. Download the ISO from `https://codostpublicassets.blob.core.windows.net/osdcloud/CoduxOSDCloud.iso`
2. Create a bootable USB with Rufus (exactly as community users will do)
3. Boot a test machine from the USB
4. Connect to WiFi when prompted
5. Verify Windows 11 deploys successfully

---

## Step 8 - Share

The only URL you need to share is:

```
https://github.com/Codux/CoduxOSDCloud
```

The README on that page guides users through the rest.

---

## Future: Changing the Deployment

To change what Windows version, edition, or language gets deployed:

1. Edit `Deployment/Deploy-Windows11.ps1`
2. Push to `main`
3. Done - the USB never needs to be rebuilt

## Future: Rebuilding the Boot Image

If you update OSD/OSDCloud modules or Windows ADK, rebuild the image:

```powershell
.\Maintenance\Refresh-BootImage.ps1
```

Then upload the new ISO to Azure Files and update `VERSION` + `CHANGELOG.md`.
