<#
.SYNOPSIS
  Displays the Utility menu, dynamically invoking UtilityModule functions.

.DESCRIPTION
  Imports MenuLibrary and DynamicModuleLoader, then loads UtilityModule.
  Discovers all exported functions from UtilityModule, builds a menu
  with one entry per function (prompting for parameters if needed),
  and lets the user invoke them interactively. Supports Esc to exit
  or Back to return to a higher‐level menu.

.NOTES
  • Place this script in your Menus folder.
  • Expects sibling Modules\MenuLibrary.psm1, DynamicModuleLoader.psm1,
    and UtilityModule.psm1.
  • Relies on Read-Input, Show-Menu, Pause, Confirm-Action from MenuLibrary.
#>
[CmdletBinding()]
param()
#region ====== Load Modules =======================================================================
$menuLib   = Join-Path $PSScriptRoot '../Modules/MenuLibrary.psm1'
$dynLoader = Join-Path $PSScriptRoot '../Modules/DynamicModuleLoader.psm1'
$utilMod   = Join-Path $PSScriptRoot '../Modules/UtilityModule.psm1'

Import-Module -Name $menuLib   -ErrorAction Stop
Import-Module -Name $dynLoader -ErrorAction Stop
Import-Module -Name $utilMod   -ErrorAction Stop
#endregion

#region ====== Discover Utility Functions =========================================================
try {
    # This will import UtilityModule if not loaded, then return its functions
    $funcs = Get-ModuleFunctionsFromScriptName -ScriptPath $MyInvocation.MyCommand.Path
}
catch {
    Write-Error "Failed to load UtilityModule: $($_.Exception.Message)"
    exit 1
}

if (-not $funcs) {
    Write-Warning 'No functions found in UtilityModule.'
    exit 0
}
#endregion

#region ====== Build Menu Entries =================================================================
$menuOptions = foreach ($f in $funcs) {
    # Build a friendly label: FooBarBaz → "Foo Bar Baz"
    $label = ($f.Name -replace '([a-z])([A-Z])','$1 $2')

    # Create an invocation scriptblock
    if ($f.Parameters.Count -gt 0) {
        # Prompt for each parameter
        $paramLines = $f.Parameters.Keys | ForEach-Object {
            "\$$_ = Read-Input -Prompt 'Enter value for parameter `$_' -Default ''"
        } -join "`n"

        # Assemble parameter hashtable
        $paramTable = '@{ ' + ($f.Parameters.Keys | ForEach-Object { "'$_' = `$$_" }) -join '; ' + ' }'

        $sbText = @"
$paramLines
$params = $paramTable
& $($f.Name) @params
"@
        $invoker = [scriptblock]::Create($sbText)
    }
    else {
        $invoker = [scriptblock]::Create("& $($f.Name)")
    }

    [PSCustomObject]@{
        Label = $label
        Value = $invoker
    }
}
# Add Back/Exit entries
$menuOptions += [PSCustomObject]@{ Label='Back'; Value='BACK' }
$menuOptions += [PSCustomObject]@{ Label='Exit'; Value='ESC' }
#endregion

#region ====== Menu Loop ==========================================================================
while ($true) {
    $choice = Show-Menu `
        -Title   (Get-MenuTitleFromFile) `
        -Options $menuOptions

    switch ($choice) {
        'ESC'  { Exit }
        'BACK' { break }

        { $_ -is [scriptblock] } {
            try {
                & $choice
            }
            catch {
                Write-Error "❌ Invocation error: $($_.Exception.Message)"
            }
            Pause -Message 'Press any key to return to the menu…'
        }

        default {
            Write-Warning "Unrecognized selection: $choice"
        }
    }
}
#endregion