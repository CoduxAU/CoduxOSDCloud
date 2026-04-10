# Prerequisites

Requirements for the **repo owner** to build the WinRE boot image and ISO.

> Community users only need the [README](../README.md) - this document is for the person maintaining the repo.

---

## Build Machine OS

> **This is the most common setup mistake.**

The WinRE boot image **must be built on a Windows 11 24H2 machine** (build 26100).

The WinRE image is sourced from the build machine's own recovery environment. A Windows 11 24H2 build machine is required to produce a Windows 11 24H2 WinRE boot image.

---

## Step 1 - Install Windows 11 24H2 with a Local Admin Account

During Windows setup, use **BypassNRO** to skip the Microsoft account requirement and create a local admin account instead:

```
https://github.com/ChrisTitusTech/bypassnro
```

Follow the instructions in that repo to bypass the online account requirement at the OOBE screen.

---

## Step 2 - Apply Codux Windows Defaults

Once logged in, open **PowerShell as Administrator** and run:

```powershell
irm defaults.codoit.com.au | iex
```

This applies the standard Codux Windows configuration baseline.

---

## Step 3 - Install Core Tools via winget

Open **Command Prompt** or **PowerShell** and run:

```powershell
winget install Microsoft.VisualStudioCode
winget install Git.Git
winget install Microsoft.PowerShell
```

Restart your terminal after installing so the new tools are on the PATH.

---

## Step 4 - Clone the Repository

```powershell
git clone https://github.com/Codux/CoduxOSDCloud.git "$env:USERPROFILE\GitHub\CoduxOSDCloud"
```

Open the folder in VS Code:

```powershell
code "$env:USERPROFILE\GitHub\CoduxOSDCloud"
```

---

## Step 5 - Set Execution Policy

PowerShell blocks unsigned scripts by default. Run this in every new PowerShell 7 session before running any scripts in this repo:

```powershell
Set-ExecutionPolicy Bypass -Scope Process
```

> This only applies to the current session — it resets when you close the terminal.

---

## Step 6 - Install Windows ADK

- Go to the ADK download page and download the latest ADK (Windows 11, version 24H2):
  `https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install`
- Download both **adksetup.exe** and **adkwinpesetup.exe**
- Run **adksetup.exe** and select **Deployment Tools** only
- Run **adkwinpesetup.exe** and select **Windows Preinstallation Environment**

---

## Step 7 - Run the Automated Prerequisite Installer

Open **PowerShell 7 as Administrator**, navigate to the repo, and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process
cd "$env:USERPROFILE\GitHub\CoduxOSDCloud"
.\Setup\Install-Prerequisites.ps1
```

This installs the OSD and OSDCloud PowerShell modules and validates the environment.

After it completes, run the verification check:

```powershell
.\Setup\Verify-Environment.ps1
```

---

## Quick Reference

| Component | Required Version | Notes |
|-----------|-----------------|-------|
| Build machine OS | Windows 11 24H2 (build 26100) | WinRE is sourced from the build machine |
| VS Code | Latest | `winget install Microsoft.VisualStudioCode` |
| Git | Latest | `winget install Git.Git` |
| PowerShell | 7.4.x or later | `winget install Microsoft.PowerShell` |
| Windows ADK | Windows 11 24H2 (build 26100.x) | Deployment Tools + WinPE add-on |
| OSD module | Latest from PSGallery | Installed by `Install-Prerequisites.ps1` |
| OSDCloud module | Latest from PSGallery | Installed by `Install-Prerequisites.ps1` |
