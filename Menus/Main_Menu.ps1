# Menus/Main_Menu.ps1
Import-Module "$PSScriptRoot/../Modules/MenuLibrary.psm1"

# Load Config
$config     = Get-GlobalConfig
$menuFolder = Resolve-Path "$PSScriptRoot"
$allFiles   = Get-ChildItem $menuFolder -Filter '*_Menu.ps1' | 
              Where-Object Name -ne 'Main_Menu.ps1'

# Order & Filter
$ordered = $config.MenuOrder |
           ForEach-Object {
             $allFiles | Where-Object BaseName -eq $_
           } |
           Where-Object { $_ }  # drop not-found
$visible = $ordered | 
           Where-Object { $config.HiddenMenus -notcontains $_.BaseName }

# Build Opts
$opts = foreach ($f in $visible) {
    # use override or auto-label
    $label = $config.LabelOverrides.$($f.BaseName) `
             ?? ($f.BaseName -replace '_Menu$','' -replace '_',' ')
    [PSCustomObject]@{ Label = $label; Value = $f.FullName }
}

# Loop
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