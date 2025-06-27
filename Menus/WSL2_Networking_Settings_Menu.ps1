# Menus/WSL2_Networking_Settings_Menu.ps1
<#
.SYNOPSIS
  WSL2 Networking Settings Menu

.DESCRIPTION
  Dynamically loads WSL2NetworkingSettingsModule and presents its exported
  functions in a centered console menu. Prompts for parameters if needed,
  invokes the selected function, and supports Back/Exit navigation.

.NOTES
  • Requires sibling Modules:
      ‑ MenuLibrary.psm1
      ‑ DynamicModuleLoader.psm1
      ‑ WSL2NetworkingSettingsModule.psm1
  • Place this script under Menus\ alongside these Modules.
#>
[CmdletBinding()]
param()

#region ====== Load Modules =======================================================================
$base        = $PSScriptRoot
$menuLib     = Join-Path $base '../Modules/MenuLibrary.psm1'
$dynLoader   = Join-Path $base '../Modules/DynamicModuleLoader.psm1'
Import-Module -Name $menuLib   -ErrorAction Stop
Import-Module -Name $dynLoader -ErrorAction Stop
#endregion

#region ====== Discover Networking Commands =======================================================
$commands = Get-ModuleFunctionsFromScriptName -ScriptPath $MyInvocation.MyCommand.Path
if (-not $commands) {
    Write-Error 'No functions found in WSL2NetworkingSettingsModule.'
    exit 1
}
#endregion

#region ====== Dynamic Menu Generator =============================================================
$menuOptions = foreach ($cmd in $commands) {
    # Friendly label
    $label = ($cmd.Name -replace '([a-z])([A-Z])','$1 $2')

    if ($cmd.Parameters.Count -gt 0) {
        # Build prompts for each parameter
        $promptLines = $cmd.Parameters.Keys | ForEach-Object {
            "\$$_ = Read-Input -Prompt 'Enter $_ for $($cmd.Name)' -Default ''"
        } -join "`n"

        # Assemble a hashtable of param values
        $hashText = '@{ ' + (
            $cmd.Parameters.Keys |
            ForEach-Object { "'$_' = `$$_" }
        ) -join '; ' + ' }'

        $scriptText = @"
$promptLines
$params = $hashText
& $($cmd.Name) @params
"@

        $invoker = [scriptblock]::Create($scriptText)
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
$menuOptions += [PSCustomObject]@{ Label = 'Back';  Value = 'BACK' }
$menuOptions += [PSCustomObject]@{ Label = 'Exit';  Value = 'ESC' }
#endregion

#region ─── Main Menu Loop ───────────────────────────────────────────────────────
while ($true) {
    $selection = Show-Menu `
        -Title   (Get-MenuTitleFromFile) `
        -Options $menuOptions

    switch ($selection) {
        'ESC'  { Exit 0 }
        'BACK' { break }

        { $_ -is [scriptblock] } {
            try {
                & $selection
            }
            catch {
                Write-Error "❌ Error: $($_.Exception.Message)"
            }
            Pause -Message 'Press any key to return…'
        }

        default {
            Write-Warning "Unrecognized selection: $selection"
            Pause -Message 'Press any key to return…'
        }
    }
}
#endregion