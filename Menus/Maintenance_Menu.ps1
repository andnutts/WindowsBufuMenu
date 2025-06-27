<#
.SYNOPSIS
  System maintenance menu for common Windows health tasks.

.DESCRIPTION
  Presents a text-based menu to run commands like SFC, DISM, CHKDSK,
  and clear temporary files. Prompts for confirmation where appropriate,
  and pages output in-console. Relies on the MenuLibrary UI helpers.

.NOTES
  • Depends on MenuLibrary.psm1 (Show-Menu, Get-MenuTitleFromFile, Confirm-Action,
    Read-Input, Pause).
  • Place this script under Menus alongside a sibling Modules and Logs folder.

.EXAMPLE
  & .\Maintenance_Menu.ps1
#>

#region ─── Load UI Helpers ───────────────────────────────────────────────────────
$menuLib = Join-Path $PSScriptRoot '../Modules/MenuLibrary.psm1'
Import-Module -Name $menuLib -ErrorAction Stop

$loader = Join-Path $PSScriptRoot '../Modules/DynamicModuleLoader.psm1'
Import-Module -Name $loader  -ErrorAction Stop
#endregion


#region ─── Define Menu Options ───────────────────────────────────────────────────
$menuOptions = @(
    [PSCustomObject]@{
        Label = 'sfc /scannow'
        Value = {
            if (Confirm-Action -Message 'Run sfc /scannow?') {
                sfc /scannow
            }
        }
    }
    [PSCustomObject]@{
        Label = 'DISM: CheckHealth'
        Value = { dism /Online /Cleanup-Image /CheckHealth }
    }
    [PSCustomObject]@{
        Label = 'DISM: RestoreHealth (full)'
        Value = { dism /Online /Cleanup-Image /RestoreHealth }
    }
    [PSCustomObject]@{
        Label = 'Schedule chkdsk C: /F'
        Value = { chkdsk C: /F }
    }
    [PSCustomObject]@{
        Label = 'Clear Temp Files'
        Value = {
            $path = Read-Input -Prompt 'Temp folder to clear' -Default $env:TEMP
            if (Confirm-Action -Message "Delete all files in `$path`?") {
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    [PSCustomObject]@{ Label = 'Exit'; Value = 'ESC' }
)
#endregion


#region ─── Main Menu Loop ────────────────────────────────────────────────────────
while ($true) {
    $choice = Show-Menu `
        -Title   (Get-MenuTitleFromFile) `
        -Options $menuOptions

    switch ($choice) {
        'ESC' {
            break
        }
        { $_ -is [scriptblock] } {
            try {
                & $choice
            }
            catch {
                Write-Error "❌ Error: $($_.Exception.Message)"
            }
            Pause -Message 'Press any key to return to the menu…'
        }
        default {
            Write-Warning "Unrecognized selection: $choice"
            Pause -Message 'Press any key to return to the menu…'
        }
    }
}
#endregion
```