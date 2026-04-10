# Config

Configuration files used by the OSDCloud deployment environment.

## Files

| File | Purpose |
|------|---------|
| `OSDCloud.json` | GUI default selections for interactive deployments via `Start-OSDCloudGUI.ps1` |

## Important Notes

### OSDCloud.json vs Deploy-Windows11.ps1

`OSDCloud.json` controls what the **GUI pre-selects** when running `Start-OSDCloudGUI.ps1` interactively. It does **not** affect `Deploy-Windows11.ps1`.

Deployment settings (OS version, edition, language) live directly in `Deploy-Windows11.ps1` as clearly commented variables. That script is the single source of truth for automated deployments.
