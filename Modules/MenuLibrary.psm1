# Modules/MenuLibrary.psm1

#region ====== Load Modules =======================================================================
#region -------- Load Global Configuration --------------------------------------------------------
Import-Module "$PSScriptRoot/Config.psm1"

# Load once into a global variable
$Global:WFMConfig = Load-GlobalConfig

# Example: expose config as a cmdlet
function Get-GlobalConfig { return $Global:WFMConfig }

#endregion ----------------------------------------------------------------------------------------
#region -------- Plugin Loader --------------------------------------------------------------------
#Import-Module "$PSScriptRoot/PluginLoader.psm1"; Import-Plugins $Global:Config.Paths.Plugins

#endregion ----------------------------------------------------------------------------------------
#region -------- i18n stub ------------------------------------------------------------------------
#Import-Module "$PSScriptRoot/I18n.psm1";       $Global:Translations = Load-Translations `
#                                                -Lang $Global:Config.Language `
#                                                -BasePath (Split-Path $PSScriptRoot)

#endregion ----------------------------------------------------------------------------------------
#region -------- Load Telemetry -------------------------------------------------------------------
#Import-Module "$PSScriptRoot/Telemetry.psm1"

#endregion ----------------------------------------------------------------------------------------

#endregion ========================================================================================

#region ====== Functions for Admin Permissions ====================================================
#region -------- Start As Administrator -----------------------------------------------------------
<#
.SYNOPSIS
    Relauch PowerShell with elevated privileges.
.PARAMETER Arguments
    Optional arguments to pass to the new process.
.EXAMPLE
    Start-AsAdmin -Arguments "-NoProfile -File `"$PSCommandPath`""
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
#endregion ----------------------------------------------------------------------------------------
#region -------- Invoke As Administrator ----------------------------------------------------------
<#
.SYNOPSIS
    Ensures the current script is running as administrator.
.DESCRIPTION
    Checks if the script is elevated; if not, re-launches the current script as an administrator.
.EXAMPLE
    Invoke-AsAdministrator
#>
function Invoke-AsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Restarting as Administrator..."
        Start-AsAdmin -Arguments $MyInvocation.MyCommand.Definition
        exit
    }
}
#endregion ----------------------------------------------------------------------------------------

#endregion ========================================================================================

#region ====== Menu Alignment and Sizing ==========================================================
#region -------- Write Centered -------------------------------------------------------------------
<#
.SYNOPSIS
    Writes a centered line to the console.
.PARAMETER Text
    The text to write.
.PARAMETER ForegroundColor
    (Optional) Specifies the output color (default: White).
.EXAMPLE
    Write-Centered -Text "Goodbye" -ForegroundColor Green
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
#endregion ----------------------------------------------------------------------------------------
#region -------- Show Centered Info ---------------------------------------------------------------
<#
.SYNOPSIS
    Displays centered information using Update-CenteredOutput.
.PARAMETER Info
    The informational text.
.EXAMPLE
    Show-CenteredInfo -Info "Welcome!"
#>
function Show-CenteredInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Info
    )
    $centeredText = Update-CenteredOutput -Text $Info
    Write-Host $centeredText
}
#endregion ----------------------------------------------------------------------------------------
#region -------- Update Centered Output -----------------------------------------------------------
<#
.SYNOPSIS
    Centers input text based on console width.
.PARAMETER Text
    The text to be centered.
.EXAMPLE
    Update-CenteredOutput -Text "Hello"
#>

function Update-CenteredOutput {
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
#endregion ----------------------------------------------------------------------------------------

#endregion ========================================================================================

#region ====== Functions for Menu =================================================================
#region -------- Confirm Action -------------------------------------------------------------------
<#
.SYNOPSIS
    Prompts the user for confirmation before proceeding with an action.
.PARAMETER Message
    The message to display to the user.
.PARAMETER Default
    The default response if the user simply presses Enter.
.EXAMPLE
    Confirm-Action -Message "Are you sure?" -Default 'N'
#>
function Confirm-Action {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Message,
        [ValidateSet('Y','N')][string] $Default = 'N'
    )
    $choices = if ($Default -eq 'Y') { '[Y]/N' } else { 'Y/[N]' }
    while ($true) {
        $resp = Read-Host "$Message $choices"
        if (-not $resp) { $resp = $Default }
        switch ($resp.ToUpper()) {
            'Y' { return $true }
            'N' { return $false }
            default { Write-Host ' Please enter Y or N.' -ForegroundColor Yellow }
        }
    }
}
#endregion  ---------------------------------------------------------------------------------------
#region -------- Pause ----------------------------------------------------------------------------
<#
.SYNOPSIS
    Pauses the script execution and waits for user input.
.DESCRIPTION
    This function displays a message prompting the user to press Enter to continue.
.PARAMETER Message
    The message to display to the user.
.EXAMPLE
    Pause -Message "Press Enter to continue..."
#>
function Pause {
    [CmdletBinding()]
    param([string]$Message = 'Press any key to continue…')
    Write-Host; Write-Host $Message -ForegroundColor DarkGray
    [Console]::ReadKey($true) | Out-Null
}
#endregion  ---------------------------------------------------------------------------------------
#region -------- Read-Input -----------------------------------------------------------------------
<#
.SYNOPSIS
    Reads user input from the console.
.DESCRIPTION
    This function prompts the user for input and returns the entered value.
.PARAMETER Prompt
    The message to display to the user.
.EXAMPLE
    $userInput = Read-Input -Prompt "Enter your name:"
#>
function Read-Input {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Prompt,
        [string]                     $Default,
        [switch]                     $AsSecureString
    )
    if ($AsSecureString) {
        return Read-Host $Prompt -AsSecureString
    }
    if ($Default) {
        $resp = Read-Host "$Prompt [$Default]"
        return if ($resp) { $resp } else { $Default }
    } else {
        return Read-Host $Prompt
    }
}
#endregion  ---------------------------------------------------------------------------------------
#region -------- Show-PageText --------------------------------------------------------------------
<#
.SYNOPSIS
    Displays a text page with pagination.
.DESCRIPTION
    This function takes a long string of text and displays it one page at a time,
    allowing the user to navigate through the text using keyboard input.
.PARAMETER Text
    The text to display.
.PARAMETER PageSize
    The number of lines to display per page.
.EXAMPLE
    Show-PageText -Text $longText -PageSize 10
#>
function Show-PagedText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $FilePath
    )
    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"; return
    }
    $lines = Get-Content $FilePath
    $pageSize = [Console]::WindowHeight - 4
    for ($i=0; $i -lt $lines.Count; $i += $pageSize) {
        Clear-Host
        $slice = $lines[$i..[math]::Min($i+$pageSize-1,$lines.Count-1)]
        $slice | ForEach-Object { Write-Host $_ }
        Write-Host; Write-Host "PgUp/PgDn Navigate pages, Esc to exit..." -ForegroundColor DarkGray
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq 'Escape') { break }
        if ($k.Key -eq 'PageUp') { $i = [math]::Max(-$pageSize, $i - 2*$pageSize) }
    }
}
#endregion  ---------------------------------------------------------------------------------------
#region -------- Show-ProgressBar -----------------------------------------------------------------
<#
.SYNOPSIS
    Displays a progress bar in the console.
.DESCRIPTION
    This function shows a progress bar in the console window, which can be used to indicate the progress of a long-running operation.
.PARAMETER Percentage
    The percentage of completion (0-100) to display on the progress bar.
.EXAMPLE
    Show-ProgressBar -Percentage 75
#>
function Show-ProgressBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]    $PercentComplete,
        [Parameter(Mandatory)][string] $Activity,
        [string]                       $Status
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}
#endregion  ---------------------------------------------------------------------------------------
#region -------- Show-Help ------------------------------------------------------------------------
<#
.SYNOPSIS
    Displays help information for the script or module.

.DESCRIPTION
    This function shows help information, including available commands and their usage.

.PARAMETER Command
    The command for which to display help information.

.EXAMPLE
    Show-Help -Command Get-MenuTitle
#>
function Show-Help {
    Clear-Host
    @"
Menu Navigation Help

  ↑ / ↓       Move selection
  PgUp/PgDn   Jump a page
  Enter       Select highlighted item
  b           Go back to previous menu
  Esc         Exit application
  h           Show this screen

Press any key to return...
"@ | Write-Host
    [Console]::ReadKey($true) | Out-Null
}
#endregion  ---------------------------------------------------------------------------------------

#endregion ========================================================================================

#region ====== Get Script Name annd set Menu Title ================================================
<#
.SYNOPSIS
    Retrieves the script name and sets it as the menu title.
.DESCRIPTION
    This function gets the name of the currently executing script, removes the file extension,
    and replaces underscores with spaces to create a user-friendly title for the menu.
.PARAMETER ScriptName
    The name of the script file (without extension) to use as the menu title.
.PARAMETER Title
    The title to set for the console window.
.EXAMPLE
    $MenuTitle = Get-MenuTitle
    Write-Host "Menu Title: $MenuTitle"
#>
function Get-MenuTitle {
    # Get the name of the currently executing script
    $scriptFileName = $MyInvocation.MyCommand.Name

    # Remove the file extension (if needed)
    $scriptFileName = [System.IO.Path]::GetFileNameWithoutExtension($scriptFileName)

    # Replace underscores with spaces
    return $scriptFileName.Replace('_', ' ')
}
#endregion ========================================================================================

#region ====== Show-Menu ==========================================================================
function Show-Menu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]   $Title,
        [Parameter(Mandatory)][object[]] $Options,   # array of @{ Label = '…'; Value = <any> }
        [int]                            $PageSize = [Console]::WindowHeight - 6
    )

    # State
    $selectedIndex = 0
    $topIndex      = 0
    $maxIndex      = $Options.Count - 1

    function Draw-Menu {
        Clear-Host
        # Header
        "`n========== $Title ==========`n"
        # Visible slice
        $slice = $Options[$topIndex..([math]::Min($topIndex + $PageSize - 1, $maxIndex))]
        for ($i = 0; $i -lt $slice.Count; $i++) {
            $globalIdx = $topIndex + $i
            if ($globalIdx -eq $selectedIndex) {
                Write-Host " > " -NoNewline -ForegroundColor Cyan
                Write-Host $slice[$i].Label -ForegroundColor White -BackgroundColor DarkBlue
            } else {
                Write-Host "   " + $slice[$i].Label
            }
        }
        "`nUse ↑ ↓ PgUp PgDn to navigate; Enter to select; b=back; Esc=exit; h=help"
    }

    while ($true) {
        Draw-Menu
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            'UpArrow' {
                if ($selectedIndex -gt 0) { $selectedIndex-- }
                if ($selectedIndex -lt $topIndex) { $topIndex = $selectedIndex }
            }
            'DownArrow' {
                if ($selectedIndex -lt $maxIndex) { $selectedIndex++ }
                if ($selectedIndex -ge $topIndex + $PageSize) {
                    $topIndex = $selectedIndex - $PageSize + 1
                }
            }
            'PageUp' {
                $selectedIndex = [math]::Max(0, $selectedIndex - $PageSize)
                $topIndex      = [math]::Max(0, $topIndex - $PageSize)
            }
            'PageDown' {
                $selectedIndex = [math]::Min($maxIndex, $selectedIndex + $PageSize)
                $topIndex      = [math]::Min($maxIndex - $PageSize + 1, $topIndex + $PageSize)
            }
            'Escape' { return 'ESC' }
            'B'       { return 'BACK' }
            'H'       { return 'HELP' }
            'Enter'   { return $Options[$selectedIndex].Value }
            default   { }
        }
    }
}
#endregion ========================================================================================

Export-ModuleMember `
     -Function Start-AsAdmin, Invoke-AsAdministrator, Get-GlobalConfig, `
                Write-Centered, Show-CenteredInfo, Update-CenteredOutput
                Confirm-Action, Pause, Read-Input, Show-PagedText, Show-ProgressBar, Show-Help, `
                Show-Menu