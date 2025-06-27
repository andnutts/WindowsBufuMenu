# Menus/Log_Viewer_Menu.ps1
Import-Module "$PSScriptRoot/../Modules/MenuLibrary.psm1"

# auto-discover .log files
$logs = Get-ChildItem "$PSScriptRoot/../Logs" -Filter '*.log' | Sort-Object LastWriteTime -Descending

$opts = $logs | ForEach-Object {
  [PSCustomObject]@{ Label = $_.Name; Value = { Show-PagedText $_.FullName } }
}

while ($true) {
  $choice = Show-Menu -Title 'View Logs' -Options $opts
  switch ($choice) {
    'ESC'  { Exit }
    'BACK' { break }
    { $_ -is [scriptblock] } {
      & $choice
      Pause
    }
  }
}
