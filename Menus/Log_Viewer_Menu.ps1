<#
.SYNOPSIS
  Log Viewer Menu

.DESCRIPTION
  Discovers all “.log” files in the Logs folder, presents them
  in a centered menu, and lets you page through each file.

.NOTES
  • Depends on MenuLibrary.psm1 (Show-Menu, Get-MenuTitleFromFile,
    Show-PagedText, Pause, etc.)
  • Place this script in your Menus folder alongside a sibling Logs folder.

.EXAMPLE
  & .\Log_Viewer_Menu.ps1
#>

#region ====== Load Core UI Helpers ===============================================================
$modulePath = Join-Path $PSScriptRoot '../Modules/MenuLibrary.psm1'
Import-Module -Name $modulePath -ErrorAction Stop
#endregion

#region ====== Discover Log Files =================================================================
$logFolder = Join-Path $PSScriptRoot '../Logs'
if (-not (Test-Path $logFolder)) {
    Write-Error "Logs folder not found: $logFolder"
    exit 1
}
$logs = Get-ChildItem -Path $logFolder -Filter '*.log' -File |
        Sort-Object LastWriteTime -Descending
#endregion

#region ====== Build Menu Options =================================================================
$menuOptions = $logs | ForEach-Object {
    [PSCustomObject]@{
        Label = $_.Name
        Value = {
            Show-PagedText -Path $_.FullName
        }
    }
}
# Add an explicit Exit option
$menuOptions += [PSCustomObject]@{ Label = 'Exit'; Value = 'ESC' }
#endregion

#region ====== Main Menu Loop =====================================================================
while ($true) {
    $title  = Get-MenuTitleFromFile
    $choice = Show-Menu -Title $title -Options $menuOptions

    switch ($choice) {
        'ESC' {
            break
        }
        { $_ -is [scriptblock] } {
            try {
                # Invoke the Show-PagedText scriptblock
                & $choice
            }
            catch {
                Write-Error "❌ Error: $($_.Exception.Message)"
            }
            Pause -Message 'Press any key to return to menu…'
        }
        default {
            Write-Warning "Unrecognized selection: $choice"
            Pause
        }
    }
}
#endregion

exit 0