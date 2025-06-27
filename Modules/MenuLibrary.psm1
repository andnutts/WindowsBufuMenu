# Modules/MenuLibrary.psm1
<#
.SYNOPSIS
  Bootstraps the WFM framework: loads global config and exposes helper APIs.

.DESCRIPTION
  Imports the Config module, reads and caches the global JSON configuration
  into $Global:WFMConfig, and exposes Get-GlobalConfig as an advanced function.
  Other subsystems (plugins, i18n, telemetry, dynamic menu loader) can be
  imported here as needed by uncommenting the relevant regions.

.NOTES
  Place this file as “Bootstrap.ps1” or similar in your script root.
#>

#region ====== Load Config Module & Initialize GlobalConfig =======================================
#region -------- Load Config Module ---------------------------------------------------------------
# Load the Config module that defines Import-GlobalConfig
Import-Module (Join-Path $PSScriptRoot 'Config.psm1') -ErrorAction Stop

# Import the JSON config into a global variable
try {
    $Global:WFMConfig = Import-GlobalConfig -ConfigPath (Resolve-Path "$PSScriptRoot/../config.json")
    Write-Verbose "Global configuration loaded successfully."
}
catch {
    Write-Error "Failed to load global config: $($_.Exception.Message)" -ErrorAction Stop
}
#endregion
#region -------- Initialize GlobalConfig ----------------------------------------------------------
<#
.SYNOPSIS
  Retrieves the cached global configuration.

.DESCRIPTION
  Returns the object loaded into $Global:WFMConfig at script startup.
  Use this in other scripts or modules to read framework settings.

.OUTPUTTYPE
  System.Management.Automation.PSCustomObject

.EXAMPLE
  PS> Get-GlobalConfig
  @{ Theme = "dark"; Paths = @{ Plugins = "C:\MyApp\Plugins" }; ... }

.NOTES
  This is a passthrough to the global variable; no reloading occurs.
#>
function Get-GlobalConfig {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    return $Global:WFMConfig
}
#endregion
#region -------- Plugin Loader ------------------------------------------------------------Disabled
<#
Import-Module (Join-Path $PSScriptRoot 'PluginLoader.psm1') -ErrorAction Stop
# Import all plugins from the configured path
$pluginsPath = $Global:WFMConfig.Paths.Plugins
if (Test-Path $pluginsPath) {
    Import-Plugins -PluginsPath $pluginsPath
}
#>
#endregion
#region -------- i18n stub ----------------------------------------------------------------Disabled
<#
Import-Module (Join-Path $PSScriptRoot 'I18n.psm1') -ErrorAction Stop
$Global:Translations = Load-Translations `
  -Lang     $Global:WFMConfig.Language `
  -BasePath (Split-Path $PSScriptRoot)
#>
#endregion
#region -------- Load Telemetry -----------------------------------------------------------Disabled
<#
Import-Module (Join-Path $PSScriptRoot 'Telemetry.psm1') -ErrorAction Stop
# Example: Send-Telemetry -EventName 'AppStart' -Properties @{ User = $env:USERNAME }
#>
#endregion
#region -------- Dynamic Menu Builder -----------------------------------------------------Disabled
<#
Import-Module (Join-Path $PSScriptRoot '../Modules/DynamicModuleLoader.psm1') -ErrorAction Stop
# In your menu scripts, call:
#   Get-ModuleFunctionsFromScriptName
#>
#endregion
#endregion ========================================================================================

#region ====== Functions for Admin Permissions ====================================================
#region -------- Start As Administrator -----------------------------------------------------------
<#
.SYNOPSIS
  Relaunch the current PowerShell session with elevated privileges.
.DESCRIPTION
  If the current process is not running as Administrator, this
  cmdlet will re-invoke PowerShell.exe with the same arguments
  under the Administrator verb. It supports ShouldProcess so
  you can confirm or suppress via -Confirm.
.PARAMETER Arguments
  Optional arguments to pass to the new PowerShell process.
.EXAMPLE
  # Relaunch your script elevated:
  Start-AsAdmin -Arguments "-NoProfile -File `"$PSCommandPath`""
.NOTES
  This cmdlet does not return any pipeline output.
#>
function Start-AsAdmin {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Arguments = ""
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = $Arguments
    $psi.Verb = "runas"
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    }
    catch {
        Write-Error "Failed to run as admin: $_"
    }
}
#endregion
#region -------- Invoke As Administrator ----------------------------------------------------------
<#
.SYNOPSIS
  Ensure the current session is running as Administrator.
.DESCRIPTION
  Checks the caller’s Windows principal. If not elevated, prints
  an informational message, calls Start-AsAdmin, and exits.
.EXAMPLE
  # At the top of a script:
  Invoke-AsAdministrator
.NOTES
  This cmdlet exits the current process if elevation is required.
#>
function Invoke-AsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Output '"Restarting as Administrator..."'
        Start-AsAdmin -Arguments $MyInvocation.MyCommand.Definition
        exit
    }
}
#endregion
#endregion ========================================================================================

#region ====== Menu Alignment and Sizing ==========================================================
#region -------- Write Centered -------------------------------------------------------------------
<#
.SYNOPSIS
  Centers input text based on console width and writes it to the host.

.DESCRIPTION
  Calculates the required left-padding to center your string, then
  emits it via Write-UI (so you get colors, no-newline support,
  and a single funnel point for future redirection).

.PARAMETER Text
  The text to center and display.

.PARAMETER ForegroundColor
  The color of the text (defaults to Gray).

.OUTPUTTYPE
  System.Void

.EXAMPLE
  Write-Centered -Text "Hello, World!" -ForegroundColor Green
#>
function Write-Centered {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [ConsoleColor]$ForegroundColor = "Gray"
    )
    $consoleWidth = [System.Console]::WindowWidth
    $padding = [math]::Floor(($consoleWidth - $Text.Length) / 2)
    $centeredText = (" " * $padding) + $Text
    Write-Host $centeredText -ForegroundColor $ForegroundColor
}
#endregion
#region -------- Show Centered Info ---------------------------------------------------------------
<#
.SYNOPSIS
  Centers & displays a single line of text.

.DESCRIPTION
  Shorthand: runs your string through Format-CenteredOutput and
  writes it (and also returns it if you need it programmatically).

.PARAMETER Info
  The text to center.

.OUTPUTTYPE
  System.String

.EXAMPLE
  $line = Show-CenteredInfo -Info "Welcome!"
  # $line now holds the padded string, too
#>
function Show-CenteredInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Info
    )
    $centeredText = Format-CenteredOutput -Text $Info
    Write-Output '$centeredText'
}
#endregion
#region -------- Format Centered Output -----------------------------------------------------------
<#
.SYNOPSIS
  Calculates the left-padding to center text in the console.

.DESCRIPTION
  Returns a new string, prefixed with spaces so that when you Write-Host it,
  it will appear centered in the current console window width.

.PARAMETER Text
  The text to center.

.OUTPUTTYPE
  System.String

.EXAMPLE
  $c = Format-CenteredOutput -Text "Hello"
  # => "     Hello"  (with enough spaces in front)
#>
function Format-CenteredOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )
    # Ensure the value isn't empty
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "No text provided."
    }
    # Center the text based on console width
    $consoleWidth = [System.Console]::WindowWidth
    $padding = [math]::Floor(($consoleWidth - $Text.Length) / 2)
    return (" " * $padding) + $Text
}
#endregion
#endregion ========================================================================================

#region ====== Functions for Menu =================================================================
#region -------- Get Resolved Script Path ---------------------------------------------------------
<#
.SYNOPSIS
  Resolves a script key into a full file path based on your config.
.DESCRIPTION
  Looks up the Scripts hashtable in your module config and returns
  the resolved absolute path. Throws if the key is missing.
.PARAMETER ScriptKey
  The key name in the config’s Scripts hashtable.
.OUTPUTTYPE
  System.String
.EXAMPLE
  $path = Get-ResolvedScriptPath -ScriptKey 'CleanUpScript'
#>
[CmdletBinding()]
[OutputType([string])]
function Get-ResolvedScriptPath {
    param(
        [Parameter(Mandatory)][string] $ScriptKey
    )

    $relative = $Global:WFMConfig.Scripts[$ScriptKey]
    if (-not $relative) {
        Throw "Script key '$ScriptKey' not found in global config."
    }

    try {
        $combined = Join-Path -Path $PSScriptRoot -ChildPath "..\$relative"
        return (Resolve-Path -Path $combined -ErrorAction Stop).ProviderPath
    }
    catch {
        Throw "Failed to resolve script path for key '$ScriptKey': $($_.Exception.Message)"
    }
}
#endregion
#region -------- Confirm Action -------------------------------------------------------------------
<#
.SYNOPSIS
  Prompts the user with a Y/N question.
.DESCRIPTION
  Displays the given message with a [Y]/N or Y/[N] choice, looping until
  the user enters a valid selection. Returns $true or $false.
.PARAMETER Message
  The prompt text to display.
.PARAMETER Default
  The default choice if the user just presses Enter: 'Y' or 'N'.
.OUTPUTTYPE
  System.Boolean
.EXAMPLE
  if (Confirm-Action -Message 'Delete all temp files?' -Default 'N') {
      Remove-Item $tempFolder -Recurse
  }
#>
[CmdletBinding()]
[OutputType([bool])]
function Confirm-Action {
    param(
        [Parameter(Mandatory)][string] $Message,
        [ValidateSet('Y','N')][string] $Default = 'N'
    )

    $choices = if ($Default -eq 'Y') { '[Y]/N' } else { 'Y/[N]' }
    while ($true) {
        $resp = Read-Host -Prompt "$Message $choices"
        if (![string]::IsNullOrWhiteSpace($resp)) {
            $resp = $resp.ToUpper()
        }
        else {
            $resp = $Default
        }

        switch ($resp) {
            'Y' { return $true }
            'N' { return $false }
            default { Write-Warning 'Please enter Y or N.' }
        }
    }
}
#endregion
#region -------- Pause ----------------------------------------------------------------------------
<#
.SYNOPSIS
  Pauses script execution until the user presses any key.
.DESCRIPTION
  Displays a prompt message and waits for a single keypress.
.PARAMETER Message
  The message to display (default: "Press any key to continue…").
.OUTPUTTYPE
  None
.EXAMPLE
  Pause -Message 'Ready to proceed?'
#>
[CmdletBinding()]
[OutputType()]
function Pause {
    param(
        [string] $Message = 'Press any key to continue…'
    )
    Write-Host $Message -ForegroundColor DarkGray
    [System.Console]::ReadKey($true) | Out-Null
}
#endregion
#region -------- Read-Input -----------------------------------------------------------------------
<#
.SYNOPSIS
  Reads user input from the console.
.PARAMETER Prompt
  Prompt text.
.PARAMETER Default
  Default value if empty.
.PARAMETER AsSecureString
  If set, returns a SecureString.
.OUTPUTTYPE
  System.String, System.Security.SecureString
#>
[CmdletBinding()]
[OutputType([string],[System.Security.SecureString])]
function Read-Input {
    param(
        [Parameter(Mandatory)][string] $Prompt,
        [string]                     $Default,
        [switch]                     $AsSecureString
    )

    if ($AsSecureString) {
        return Read-Host -Prompt $Prompt -AsSecureString
    }

    if ($PSBoundParameters.ContainsKey('Default')) {
        $response = Read-Host -Prompt "$Prompt [$Default]"
        return if ([string]::IsNullOrWhiteSpace($response)) { $Default } else { $response }
    }

    return Read-Host -Prompt $Prompt
}
#endregion
#region -------- Show-PageText --------------------------------------------------------------------
<#
.SYNOPSIS
  Displays a text file one page at a time.
.PARAMETER FilePath
  Path of the file to display.
.OUTPUTTYPE
  None
#>
[CmdletBinding()]
[OutputType()]
function Show-PagedText {
    param(
        [Parameter(Mandatory)][string] $FilePath
    )

    if (-not (Test-Path -Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return
    }

    $lines    = Get-Content -Path $FilePath
    $pageSize = [System.Console]::WindowHeight - 4
    $pos      = 0

    while ($pos -lt $lines.Count) {
        Clear-Host
        $end = [math]::Min($pos + $pageSize - 1, $lines.Count - 1)
        $lines[$pos..$end] | ForEach-Object { Write-Host $_ }
        Write-Host "`nPgUp/PgDn to navigate, Esc to exit." -ForegroundColor DarkGray

        $key = [System.Console]::ReadKey($true)
        switch ($key.Key) {
            'PageDown' { $pos = [math]::Min($pos + $pageSize, $lines.Count) }
            'PageUp'   { $pos = [math]::Max($pos - $pageSize, 0) }
            'Escape'   { break }
            default    { }  # ignore other keys
        }
    }
}
#endregion
#region -------- Show-ProgressBar -----------------------------------------------------------------
<#
.SYNOPSIS
  Displays a console progress bar.
.DESCRIPTION
  Wraps the built-in Write-Progress cmdlet to show percentage, activity, and status.
.PARAMETER PercentComplete
  The completion percentage (0–100).
.PARAMETER Activity
  The high-level operation name.
.PARAMETER Status
  An optional detailed status message.
.OUTPUTTYPE
  None
#>
[CmdletBinding()]
[OutputType()]
function Show-ProgressBar {
    param(
        [Parameter(Mandatory)][int]    $PercentComplete,
        [Parameter(Mandatory)][string] $Activity,
        [string]                       $Status
    )

    Write-Progress `
      -Activity      $Activity `
      -Status        $Status `
      -PercentComplete $PercentComplete
}
#endregion
#region -------- Show-Help ------------------------------------------------------------------------
<#
.SYNOPSIS
  Shows keybindings and shortcuts for the menu system.
.DESCRIPTION
  Clears the screen, writes out a help page with navigation hints,
  then waits for any key before returning.
.OUTPUTTYPE
  None
#>
[CmdletBinding()]
[OutputType()]
function Show-Help {
    Clear-Host
    $helpText = @"
Menu Navigation Help

  ↑ / ↓       Move selection
  PgUp / PgDn Jump a page
  Enter       Select highlighted item
  b           Go back to previous menu
  Esc         Exit application
  h           Show this help screen

Press any key to return...
"@
    $helpText.Split("`n") | ForEach-Object { Write-Host $_ }
    [System.Console]::ReadKey($true) | Out-Null
}
#endregion
#endregion ========================================================================================

#region ====== Get Script Name annd set Menu Title ================================================
<#
.SYNOPSIS
  Generates a user-friendly menu title from a script’s file name.

.DESCRIPTION
  Takes a file path (defaulting to the currently executing script),
  strips off its extension, replaces underscores/dashes with spaces,
  trims any extra whitespace, and returns the result.

.PARAMETER Path
  The full path to a script file. If omitted, defaults to the caller’s script.

.OUTPUTTYPE
  System.String

.EXAMPLE
  PS> Get-MenuTitleFromFile -Path "C:\Tools\My_Script-Job.ps1"
  My Script Job

.EXAMPLE
  PS> & ".\Menus\Main_Menu.ps1" | Get-MenuTitleFromFile
  Main Menu
#>
function Get-MenuTitleFromFile {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$Path = $MyInvocation.MyCommand.Path
    )

    if (-not $Path) {
        Write-Warning 'Unable to determine script path.'
        return 'Untitled Menu'
    }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    return ($base -replace '[_\-]', ' ').Trim()
}
#endregion ========================================================================================

#region ====== Show-Menu ==========================================================================
<#
.SYNOPSIS
  Renders a console menu and returns the selected value.
.DESCRIPTION
  Displays a list of labeled options centered in the console window.
  Use arrow keys or PageUp/PageDown to move; Enter to select; Esc to exit; b to go back; h for help.
.PARAMETER Title
  The menu header text.
.PARAMETER Options
  Array of objects with `.Label` and `.Value` properties.
.PARAMETER FgColor
  Foreground color for un-selected items.
.PARAMETER BgColor
  Background color for un-selected items.
.PARAMETER SelFgColor
  Foreground color for the selected item.
.PARAMETER SelBgColor
  Background color for the selected item.
.OUTPUTTYPE
  System.String
.EXAMPLE
  $choice = Show-Menu -Title 'Main Menu' -Options $menuItems
.NOTES
  Relies on Write-UI and Format-CenteredOutput helpers.
#>
function Show-Menu {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)][string]   $Title,
        [Parameter(Mandatory)][object[]] $Options,
        [string]                         $FgColor,
        [string]                         $BgColor,
        [string]                         $SelFgColor,
        [string]                         $SelBgColor
    )

    # Ensure config and Appearance defaults exist
    if (-not $Global:WFMConfig.Appearance) {
        $Global:WFMConfig.Appearance = @{}
    }
    $app      = $Global:WFMConfig.Appearance
    $defaults = @{
        FgColor    = 'White'
        BgColor    = 'DarkBlue'
        SelFgColor = 'Black'
        SelBgColor = 'Cyan'
    }

    # Determine palette
    $FgColor    = if ($PSBoundParameters.ContainsKey('FgColor') -and $FgColor)    { $FgColor    }
                   elseif ($app.FgColor)    { $app.FgColor    } else { $defaults.FgColor }
    $BgColor    = if ($PSBoundParameters.ContainsKey('BgColor') -and $BgColor)    { $BgColor    }
                   elseif ($app.BgColor)    { $app.BgColor    } else { $defaults.BgColor }
    $SelFgColor = if ($PSBoundParameters.ContainsKey('SelFgColor') -and $SelFgColor) { $SelFgColor }
                   elseif ($app.SelFgColor) { $app.SelFgColor } else { $defaults.SelFgColor }
    $SelBgColor = if ($PSBoundParameters.ContainsKey('SelBgColor') -and $SelBgColor) { $SelBgColor }
                   elseif ($app.SelBgColor) { $app.SelBgColor } else { $defaults.SelBgColor }

    # Parse to [ConsoleColor]
    try { $Fg   = [ConsoleColor]::Parse([ConsoleColor], $FgColor)    } catch { $Fg   = [ConsoleColor]$defaults.FgColor }
    try { $Bg   = [ConsoleColor]::Parse([ConsoleColor], $BgColor)    } catch { $Bg   = [ConsoleColor]$defaults.BgColor }
    try { $SelF = [ConsoleColor]::Parse([ConsoleColor], $SelFgColor) } catch { $SelF = [ConsoleColor]$defaults.SelFgColor }
    try { $SelB = [ConsoleColor]::Parse([ConsoleColor], $SelBgColor) } catch { $SelB = [ConsoleColor]$defaults.SelBgColor }

    $width    = [Console]::WindowWidth
    $index    = 0
    $maxIndex = $Options.Count - 1

    while ($true) {
        Clear-Host

        # Title
        $t = "  $Title  "
        $padT = [Math]::Floor(($width - $t.Length)/2)
        Write-Host (' ' * $padT) -NoNewline
        Write-Host $t -ForegroundColor $SelF -BackgroundColor $SelB
        Write-Host ''

        # Options
        for ($i = 0; $i -le $maxIndex; $i++) {
            $lbl  = "  $($Options[$i].Label)  "
            $pad  = [Math]::Floor(($width - $lbl.Length)/2)
            Write-Host (' ' * $pad) -NoNewline
            if ($i -eq $index) {
                Write-Host $lbl -ForegroundColor $SelF -BackgroundColor $SelB
            } else {
                Write-Host $lbl -ForegroundColor $Fg -BackgroundColor $Bg
            }
        }

        Write-Host ''
        $hint = '↑/↓ nav   PgUp/PgDn page   Enter select   b back   Esc exit   h help'
        $padH = [Math]::Floor(($width - $hint.Length)/2)
        Write-Host (' ' * $padH) -NoNewline
        Write-Host $hint -ForegroundColor DarkGray

        # Key handling
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow'   { if ($index -gt 0)         { $index-- } }
            'DownArrow' { if ($index -lt $maxIndex) { $index++ } }
            'PageUp'    { $index = [Math]::Max(0,      $index - 5) }
            'PageDown'  { $index = [Math]::Min($maxIndex,$index + 5) }
            'Escape'    { return 'ESC' }
            'B'         { return 'BACK' }
            'H'         { if (Get-Command Show-Help -ErrorAction SilentlyContinue) { Show-Help }; continue }
            'Enter'     { return $Options[$index].Value }
            default     { continue }
        }
    }
}
#endregion

#region ====== Export Module Member ===============================================================
# Publicly exposed functions from MenuLibrary.psm1
$publicFns = @(
    'Start-AsAdmin'
    'Invoke-AsAdministrator'
    'Get-GlobalConfig'
    'Get-ResolvedScriptPath'
    'Get-MenuTitleFromFile'
    'Write-Centered'
    'Format-CenteredOutput'
    'Show-CenteredInfo'
    'Confirm-Action'
    'Pause'
    'Read-Input'
    'Show-PagedText'
    'Show-ProgressBar'
    'Show-Help'
    'Show-Menu'
)

Export-ModuleMember -Function $publicFns

#endregion