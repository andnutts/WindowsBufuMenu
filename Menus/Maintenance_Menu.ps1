# Menus/Maintenance_Menu.ps1
Import-Module "$PSScriptRoot/../Modules/MenuLibrary.psm1"

$opts = @(
  @{ Label='sfc /scannow'                  ; Value={ if (Confirm-Action 'Run sfc /scannow?' 'Y') { sfc /scannow } } }
  @{ Label='DISM: CheckHealth'             ; Value={ dism /Online /Cleanup-Image /CheckHealth } }
  @{ Label='DISM: RestoreHealth (full)'    ; Value={ dism /Online /Cleanup-Image /RestoreHealth } }
  @{ Label='Schedule chkdsk C: /F'         ; Value={ chkdsk C: /F } }
  @{ Label='Clear Temp Files'              ; Value={
      $path = Read-Input -Prompt 'Temp folder to clear [%TEMP%]' -Default $env:TEMP
      if (Confirm-Action "Delete all files in `$path`?") {
        Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
      }
    } 
  }
)

while ($true) {
  $choice = Show-Menu -Title 'Maintenance' -Options $opts
  switch ($choice) {
    'ESC'  { Exit }
    'BACK' { break }
    { $_ -is [scriptblock] } {
      & $choice
      Pause
    }
  }
}
