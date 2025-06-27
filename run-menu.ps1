# run-menu.ps1

<#
.SYNOPSIS
  Bootstrapper for WindowsBufuMenu.
.DESCRIPTION
  Loads config, core modules, plugins, then launches Main_Menu.ps1.
#>
#region ====== Determine project root =============================================================
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

#endregion ========================================================================================

#region ====== Prepare paths ======================================================================
$ModulesPath = Join-Path $ProjectRoot 'Modules'
$MenusPath   = Join-Path $ProjectRoot 'Menus'

#endregion ========================================================================================

#region ====== Add Modules folder to module search path ===========================================
$env:PSModulePath = "$ModulesPath;$env:PSModulePath"

#endregion ========================================================================================

#region ====== Import Config & load into global ===================================================
Import-Module (Join-Path $ModulesPath 'Config.psm1') -Force
$Global:WFMConfig = Import-GlobalConfig

#endregion ========================================================================================

#region ====== Import MenuLibrary (core menu engine) ==============================================
Import-Module (Join-Path $ModulesPath 'MenuLibrary.psm1') -Force

#endregion ========================================================================================

#region ====== Optionally import plugins ==========================================================
if ($Global:WFMConfig.Paths.Plugins) {
    Import-Module (Join-Path $ModulesPath 'PluginLoader.psm1') -Force
    Import-Plugins (Join-Path $ProjectRoot $Global:WFMConfig.Paths.Plugins)
}

#endregion ========================================================================================

#region ====== Launch the main menu ===============================================================
$main = Join-Path $MenusPath 'Main_Menu.ps1'
if (-not (Test-Path $main)) {
    Write-Error "Could not find Main_Menu.ps1 at $main"
    exit 1
}
& $main
#endregion ========================================================================================