# Prerequisites

Requirements for the **repo owner** to build the WinRE boot image and ISO.

> Community users only need the [README](../README.md) - this document is for the person maintaining the repo.

---

## Build Machine OS

> **This is the most common setup mistake.**

The WinRE boot image **must be built on a Windows 11 24H2 machine** (build 26100).

The WinRE image is sourced from the build machine's own recovery environment. A Windows 11 24H2 build machine is required to produce a Windows 11 24H2 WinRE boot image.

---

## Required Tools

### 1. PowerShell 7

- Download: https://github.com/PowerShell/PowerShell/releases/latest
- Look for `PowerShell-7.x.x-win-x64.msi`
- Install, then verify: `pwsh.exe --version`

### 2. Windows ADK for Windows 11, version 24H2 - Deployment Tools only

- Go to the ADK download page and download the latest ADK (Windows 11, version 24H2):
  `https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install`
- Download both **adksetup.exe** and **adkwinpesetup.exe**
- Run **adksetup.exe** and select **Deployment Tools** only
- Run **adkwinpesetup.exe** and select **Windows Preinstallation Environment**

### 3. OSD PowerShell Module

```powershell
Install-Module OSD -Force -Scope AllUsers
```

### 4. OSDCloud PowerShell Module

```powershell
Install-Module OSDCloud -Force -Scope AllUsers
```

---

## Automated Install

Run `Setup/Install-Prerequisites.ps1` as Administrator in PowerShell 7 - it will scan for missing components and install them in the correct order.

```powershell
# In PowerShell 7, as Administrator
.\Setup\Install-Prerequisites.ps1
```

After it completes, run the verification check:

```powershell
.\Setup\Verify-Environment.ps1
```

---

## Quick Reference

| Component | Required Version | Notes |
|-----------|-----------------|-------|
| Build machine OS | Windows 11 24H2 (build 26100) | WinRE is sourced from the build machine |
| PowerShell | 7.4.x or later | Also needs PS 5.1 for some cmdlets |
| Windows ADK | Windows 11 24H2 (build 26100.x) | Deployment Tools + WinPE add-on |
| OSD module | Latest from PSGallery | `Install-Module OSD` |
| OSDCloud module | Latest from PSGallery | `Install-Module OSDCloud` |
