# Menus/Main_Menu.ps1

#region ====== Load Modules =======================================================================
# Import-Module "$PSScriptRoot/../Modules/MenuLibrary.psm1"
$modRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $modRoot '..\Modules\Config.psm1')     -Force
$Global:WFMConfig = Import-GlobalConfig                         # pulls in config.json
Import-Module (Join-Path $modRoot '..\Modules\MenuLibrary.psm1') -Force

#endregion ========================================================================================

#region ====== Load Config ========================================================================
$config     = Get-GlobalConfig
if (-not $config.MenuOrder)     { $config.MenuOrder = @() }
if (-not $config.HiddenMenus)   { $config.HiddenMenus = @() }
if (-not $config.LabelOverrides){ $config.LabelOverrides = @{} }
$menuFolder = Resolve-Path "$PSScriptRoot"
$allFiles   = @(Get-ChildItem $menuFolder -Filter '*_Menu.ps1' |
              Where-Object Name -ne 'Main_Menu.ps1')

#endregion ========================================================================================

#region ====== Dynamic Menu =======================================================================
#region -------- Order & Filter -------------------------------------------------------------------
$ordered = $config.MenuOrder |
           ForEach-Object {
             $allFiles | Where-Object BaseName -eq $_
           } |
           Where-Object { $_ }  # drop not-found
$visible = $ordered |
           Where-Object { $config.HiddenMenus -notcontains $_.BaseName }

#endregion ----------------------------------------------------------------------------------------
#region -------- Options --------------------------------------------------------------------------
$opts = $visible | ForEach-Object {
    # use override or auto-label
    $label = if ($config.LabelOverrides.$($_.BaseName)) {
        $config.LabelOverrides.$($_.BaseName)
    } else {
        $_.BaseName -replace '_Menu$','' -replace '_',' '
    }
    [PSCustomObject]@{ Label = $label; Value = $_.FullName }
}
#endregion ----------------------------------------------------------------------------------------
#region -------- Menu Loop ------------------------------------------------------------------------
while ($true) {
    $sel = Show-Menu -Title $config.ProjectName -Options $opts
    switch ($sel) {
      'ESC'  { Exit }
      'BACK' { break }
      default {
        if (Test-Path $sel) { & $sel }
      }
    }
}
#endregion ----------------------------------------------------------------------------------------

#endregion ========================================================================================