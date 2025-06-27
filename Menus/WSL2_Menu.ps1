# Menus/WSL2_Menu.ps1
<#
.SYNOPSIS
  WSL2 Utility Menu

.DESCRIPTION
  Dynamically loads WSL2Module functions and presents them
  in a centered console menu. Prompts for parameters where needed,
  then invokes the chosen function. Supports Esc to exit, Back
  to return.

.NOTES
  • Requires sibling Modules:
    – MenuLibrary.psm1 (Show-Menu, Get-MenuTitleFromFile, Pause, etc.)
    – DynamicModuleLoader.psm1 (Get-ModuleFunctionsFromScriptName)
    – WSL2Module.psm1 (your WSL2 helper cmdlets)
  • Place this under Menus\, run it with PowerShell 5.1+.

.EXAMPLE
  & .\WSL2_Menu.ps1
#>
[CmdletBinding()]
param()

#region ====== Load Modules =======================================================================
$base = $PSScriptRoot
Import-Module (Join-Path $base '../Modules/MenuLibrary.psm1')         -ErrorAction Stop
Import-Module (Join-Path $base '../Modules/DynamicModuleLoader.psm1') -ErrorAction Stop
Import-Module (Join-Path $base '../Modules/WSL2Module.psm1')          -ErrorAction Stop
#endregion

#region ─── Discover WSL2 Commands ─────────────────────────────────────────────────
# Auto‐import and list all exported functions from WSL2Module.psm1
$wsldCmds = Get-ModuleFunctionsFromScriptName -ScriptPath $MyInvocation.MyCommand.Path
if (-not $wsldCmds) {
    Write-Error 'No WSL2Module functions found; aborting menu.'
    exit 1
}
#endregion

#region ====== Build Dynamic Menu Options =========================================================
$menuOptions = foreach ($cmd in $wsldCmds) {
    $label = ($cmd.Name -replace '([a-z])([A-Z])','$1 $2')

    if ($cmd.Parameters.Count -gt 0) {
        # Prompt for each parameter, then invoke
        $paramPrompts = $cmd.Parameters.Keys | ForEach-Object {
            "\$$_ = Read-Input -Prompt 'Enter $_ for $($cmd.Name)' -Default ''"
        } -join "`n"
        $paramTable = '@{ ' + ($cmd.Parameters.Keys | ForEach-Object { "'$_' = `$$_" }) -join '; ' + ' }'
        $sbText = @"
$paramPrompts
$params = $paramTable
& $($cmd.Name) @params
"@
        $invoker = [scriptblock]::Create($sbText)
    }
    else {
        $invoker = [scriptblock]::Create("& $($cmd.Name)")
    }

    [PSCustomObject]@{
        Label = $label
        Value = $invoker
    }
}
# Add navigation entries
$menuOptions += [PSCustomObject]@{ Label='Back'; Value='BACK' }
$menuOptions += [PSCustomObject]@{ Label='Exit'; Value='ESC' }
#endregion

#region ====== Menu Loop ==========================================================================
while ($true) {
    $choice = Show-Menu `
        -Title   (Get-MenuTitleFromFile) `
        -Options $menuOptions

    switch ($choice) {
        'ESC'  { Exit 0 }
        'BACK' { break }

        { $_ -is [scriptblock] } {
            try {
                & $choice
            }
            catch {
                Write-Error "❌ Error in function: $($_.Exception.Message)"
            }
            Pause -Message 'Press any key to return to menu…'
        }

        default {
            Write-Warning "Unrecognized selection: $choice"
            Pause -Message 'Press any key to return to menu…'
        }
    }
}
#endregion
```