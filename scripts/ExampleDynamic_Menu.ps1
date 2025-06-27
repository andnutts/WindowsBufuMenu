# Menus/ExampleDynamic_Menu.ps1

#region ====== Load Modules =======================================================================
#region -------- Load Global Configuration --------------------------------------------------------
Import-Module "$PSScriptRoot/Config.psm1"

# Load once into a global variable
$Global:WFMConfig = Import-GlobalConfig

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-GlobalConfig { return $Global:WFMConfig }

#endregion ----------------------------------------------------------------------------------------
#region -------- Dynamic Menu Builder -------------------------------------------------------------
Import-Module "$PSScriptRoot/../Modules/DynamicModuleLoader.psm1"   # Dynamic Menu Builder
#endregion ----------------------------------------------------------------------------------------
#region -------- Plugin Loader ------------------------------------------------------------Disabled
<# Disabled
Import-Module "$PSScriptRoot/PluginLoader.psm1"; Import-Plugins $Global:Config.Paths.Plugins
#>
#endregion ----------------------------------------------------------------------------------------
#region -------- i18n stub ----------------------------------------------------------------Disabled
<# Disabled
Import-Module "$PSScriptRoot/I18n.psm1";       $Global:Translations = Load-Translations `
                                                -Lang $Global:Config.Language `
                                                -BasePath (Split-Path $PSScriptRoot)
#>
#endregion ----------------------------------------------------------------------------------------
#region -------- Load Telemetry -----------------------------------------------------------Disabled
<# Disabled
#Import-Module "$PSScriptRoot/Telemetry.psm1"
#>
#endregion ----------------------------------------------------------------------------------------
#endregion ========================================================================================

#region ====== Menu ===============================================================================
#region -------- Get the base name of the script (e.g., "WSL2_Menu.ps1" → "WSL2") -----------------
$scriptBaseName = (Get-MenuTitleFromFile) -replace ' Menu$', ''
#endregion ----------------------------------------------------------------------------------------
#region -------- Setup Dynamic Menu Options -------------------------------------------------------
#region ----------- Construct the expected module name (e.g., "WSL2" → "WSL2Module") --------------
$moduleName = "${scriptBaseName}Module"
#endregion ----------------------------------------------------------------------------------------
#region ----------- Attempt to import the module if not already loaded ----------------------------
if (-not (Get-Module -Name $moduleName)) {
    try {
      Import-Module "$PSScriptRoot/../Modules/$moduleName.psm1" -ErrorAction Stop
    } catch {
        Write-Warning "Could not load module: $moduleName"
        return
    }
}
#endregion ----------------------------------------------------------------------------------------
#region ----------- Discover all exported functions from the inferred module ----------------------
$funcs = Get-Command -Module $moduleName -CommandType Function | Sort-Object Name
#endregion ----------------------------------------------------------------------------------------
#region ----------- Build Dynamic Menu Options ----------------------------------------------------
$opts = foreach ($f in $funcs) {
    # turn FooBarBaz into "Foo Bar Baz"
    $label = ($f.Name -replace '([a-z])([A-Z])','$1 $2')

    # if function has parameters, build a SB that prompts for each one
    if ($f.Parameters.Count -gt 0) {
        $paramPrompts = $f.Parameters.Keys | ForEach-Object {
            "`$$_ = Read-Input -Prompt 'Enter $_ for $($f.Name)'"
        } -join "`n"

        $paramArray = '$params = @(' + (
            $f.Parameters.Keys | ForEach-Object { "`$$_" }
        ) -join ', ' + ')'

        $sbText = @"
$paramPrompts
$paramArray
& $($f.Name) @params
"@

        $sb = [scriptblock]::Create($sbText)
    }
    else {
        # no parameters ⇒ just invoke
        $sb = [scriptblock]::Create("& $($f.Name)")
    }

    [PSCustomObject]@{
        Label = $label
        Value = $sb
    }
}
#endregion ----------------------------------------------------------------------------------------
#endregion ----------------------------------------------------------------------------------------
#endregion ========================================================================================

#region ====== Menu Loop ==========================================================================
while ($true) {
    $menuChoice = Show-Menu `
        -Title (Get-MenuTitleFromFile) `
        -Options $opts

    switch ($menuChoice) {
        'ESC'  { Exit }
        'BACK' { break }

        # handle scriptblocks (your most common case)
        { $_ -is [scriptblock] } {
            try {
                & $menuChoice
            }
            catch {
                Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            Pause
        }

        # if it’s a string path, dot-source it
        default {
            if (Test-Path $menuChoice) {
                . $menuChoice
                Pause
            } else {
                Write-Host "⚠️  Unrecognized menu return value: $menuChoice" -ForegroundColor Yellow
                Pause
            }
        }
    }
}
#endregion ========================================================================================