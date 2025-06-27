<#
.SYNOPSIS
  Customize menu appearance (colors) at runtime.

.DESCRIPTION
  Loads the global config.json, ensures an Appearance node exists,
  then presents a menu for setting FgColor, BgColor, SelFgColor, and SelBgColor.
  Selections are saved back to config.json.

.NOTES
  • Depends on: MenuLibrary.psm1 (Show-Menu, Get-MenuTitleFromFile, Confirm-Action,
    Read-Input, Pause, etc.), Config.psm1 (Import-GlobalConfig).
  • Make sure config.json has a top‐level “Appearance” hashtable.
#>
#───────────────────────────────────────────────────────────────────────────────
#region Load Modules
Import-Module (Join-Path $PSScriptRoot '../Modules/MenuLibrary.psm1') -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '../Modules/Config.psm1')       -ErrorAction Stop
#endregion

#region Load Config
$configPath = Resolve-Path -Path (Join-Path $PSScriptRoot '../config.json')
$config     = Import-GlobalConfig -ConfigPath $configPath
#endregion

#region Ensure Appearance Exists
if (-not $config.PSObject.Properties.Match('Appearance')) {
    $config | Add-Member NoteProperty Appearance @{}
}
#endregion

#region Local Functions
<#
.SYNOPSIS
  Saves the in-memory config back to disk.
#>
function Save-Config {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $ConfigObject)
    try {
        $ConfigObject | ConvertTo-Json -Depth 5 |
          Set-Content -Path $configPath -Encoding UTF8
        Write-Verbose "Config saved to $configPath"
    }
    catch {
        Write-Error "Failed to save config: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
  Prompts user to pick a ConsoleColor for a config property.
.PARAMETER PropName
  The key under config.Appearance (e.g. 'FgColor').
.PARAMETER Title
  Menu title text.
#>
function Edit-Color {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $PropName,
        [Parameter(Mandatory)][string] $Title
    )

    # Build color list once
    $colorOpts = [Enum]::GetNames([ConsoleColor]) |
      Sort-Object |
      ForEach-Object { [PSCustomObject]@{ Label = $_; Value = $_ } }

    $choice = Show-Menu -Title $Title -Options $colorOpts
    if ($choice -in 'ESC','BACK') { return }

    $config.Appearance.$PropName = $choice
    Save-Config -ConfigObject $config
    Write-Host "↪  Set $PropName to $choice" -ForegroundColor Green
    Pause -Message 'Press any key to continue…'
}
#endregion

#region Build Menu Actions
$menuActions = @(
    [PSCustomObject]@{
        Label = 'Foreground Color'
        Value = { Edit-Color -PropName 'FgColor'    -Title 'Select Foreground Color' }
    }
    [PSCustomObject]@{
        Label = 'Background Color'
        Value = { Edit-Color -PropName 'BgColor'    -Title 'Select Background Color' }
    }
    [PSCustomObject]@{
        Label = 'Selected Fg Color'
        Value = { Edit-Color -PropName 'SelFgColor' -Title 'Select Selected Fg Color' }
    }
    [PSCustomObject]@{
        Label = 'Selected Bg Color'
        Value = { Edit-Color -PropName 'SelBgColor' -Title 'Select Selected Bg Color' }
    }
    [PSCustomObject]@{
        Label = 'Reset to Theme Defaults'
        Value = {
            # Reset per theme
            switch ($config.Theme) {
                'dark' {
                    $config.Appearance = @{
                        FgColor    = 'Gray'
                        BgColor    = 'DarkCyan'
                        SelFgColor = 'White'
                        SelBgColor = 'DarkMagenta'
                    }
                }
                'light' {
                    $config.Appearance = @{
                        FgColor    = 'Black'
                        BgColor    = 'White'
                        SelFgColor = 'White'
                        SelBgColor = 'DarkBlue'
                    }
                }
                default {
                    $config.Appearance = @{
                        FgColor    = 'White'
                        BgColor    = 'DarkBlue'
                        SelFgColor = 'Black'
                        SelBgColor = 'Cyan'
                    }
                }
            }
            Save-Config -ConfigObject $config
            Write-Host '↪  Reset complete' -ForegroundColor Green
            Pause -Message 'Press any key to continue…'
        }
    }
    [PSCustomObject]@{ Label = 'Back'; Value = 'BACK' }
    [PSCustomObject]@{ Label = 'Exit'; Value = 'ESC' }
)
#endregion

#region Menu Loop
while ($true) {
    $choice = Show-Menu `
        -Title   (Get-MenuTitleFromFile) `
        -Options $menuActions

    switch ($choice) {
        'ESC'  { Exit }
        'BACK' { break }
        { $_ -is [scriptblock] } {
            try { & $choice }
            catch {
                Write-Error "❌ Error: $($_.Exception.Message)"
            }
        }
        default {
            Write-Warning "Unknown choice: $choice"
        }
    }
}
#endregion
```