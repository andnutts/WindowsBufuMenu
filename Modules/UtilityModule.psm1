# Modules/UtilityModule.psm1

#region ====== Logging Functions ==================================================================
#region -------- Write Log ------------------------------------------------------------------------
#───────────────────────────────────────────────────────────────────────────────
<#
.SYNOPSIS
  Writes a timestamped, colored log entry to the host.
.DESCRIPTION
  Emits a log line prefixed with [YYYY-MM-DD HH:MM:SS] and the log level.
  INFO→Write-Host (Green), WARN→Write-Warning, ERROR→Write-Error,
  DEBUG→Write-Debug (hidden unless -Debug).
.PARAMETER Level
  One of INFO, WARN, ERROR or DEBUG.
.PARAMETER Message
  The message text to log.
.PARAMETER Color
  Optional override for the text color (ConsoleColor).
.EXAMPLE
  Write-Log -Level INFO -Message 'Operation complete.'
.NOTES
  No objects are emitted; this is purely a host writer.
#>
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('INFO','WARN','ERROR','DEBUG')][string] $Level,
        [Parameter(Mandatory)][string] $Message,
        [ConsoleColor] $Color
    )
    $time = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    switch ($Level) {
      'INFO'  { $clr = $Color ?? 'Green' }
      'WARN'  { $clr = $Color ?? 'Yellow' }
      'ERROR' { $clr = $Color ?? 'Red' }
      'DEBUG' { $clr = $Color ?? 'DarkGray' }
    }
    Write-Output '"[$time] [$Level] $Message" -ForegroundColor $clr'
}
#endregion ----------------------------------------------------------------------------------------
#endregion ========================================================================================

#region ====== JSON Helpers =======================================================================
#region ----------- Get JSON ----------------------------------------------------------------------
<#
.SYNOPSIS
  Reads a JSON file and converts to objects.
.DESCRIPTION
  Loads the entire file as text and invokes ConvertFrom-Json.
.PARAMETER Path
  Path to the .json file.
.OUTPUTTYPE
  Deserialized JSON object (custom PS objects, arrays, primitives).
.EXAMPLE
  $cfg = Get-Json -Path .\config.json
.NOTES
  Throws if the file is missing or invalid JSON.
#>
function Get-Json {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path
    )
    if (-not (Test-Path $Path)) {
        throw "JSON file not found: $Path"
    }
    Get-Content $Path -Raw | ConvertFrom-Json
}
#endregion ----------------------------------------------------------------------------------------
#region ----------- Save JSON ---------------------------------------------------------------------
<#
.SYNOPSIS
  Serializes an object as JSON and saves to a file.
.DESCRIPTION
  Uses ConvertTo-Json with configurable depth and writes UTF8 text.
.PARAMETER Object
  The object graph to serialize.
.PARAMETER Path
  Destination file path.
.PARAMETER Depth
  Maximum JSON depth (default 5).
.EXAMPLE
  Save-Json -Object $cfg -Path .\config.json -Depth 10
.NOTES
  Overwrites the file if it already exists.
#>
function Save-Json {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object] $Object,
        [Parameter(Mandatory)][string] $Path,
        [int] $Depth = 5
    )
    $j = $Object | ConvertTo-Json -Depth $Depth
    $j | Set-Content -Path $Path -Encoding utf8
}
#endregion ----------------------------------------------------------------------------------------
#endregion ========================================================================================

#region ====== Execution Timing ===================================================================
#region ----------- Measure ExecutionTime ---------------------------------------------------------
<#
.SYNOPSIS
  Measures the elapsed time of a scriptblock.
.DESCRIPTION
  Runs the scriptblock, times it, and returns a PSCustomObject with
  Elapsed (TimeSpan) and TotalSeconds (Double).
.PARAMETER Script
  The scriptblock to execute.
.OUTPUTTYPE
  System.Management.Automation.PSCustomObject
.EXAMPLE
  $result = Measure-ExecutionTime { Start-Sleep 2 }
  "$($result.TotalSeconds) seconds"
.NOTES
  Does not catch exceptions; they bubble up.
#>
function Measure-ExecutionTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock] $Script
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $Script
    $sw.Stop()
    return [PSCustomObject]@{
        Elapsed     = $sw.Elapsed
        TotalSeconds= [math]::Round($sw.Elapsed.TotalSeconds, 3)
    }
}
#endregion ----------------------------------------------------------------------------------------
#endregion ========================================================================================

#region ====== File & Archive =====================================================================
#region --------- Compress Folder -----------------------------------------------------------------
<#
.SYNOPSIS
  Compresses a folder to a ZIP archive.
.DESCRIPTION
  Creates (or replaces) a .zip file from the contents of a directory.
.PARAMETER SourceDir
  The directory to compress.
.PARAMETER DestinationZip
  The output .zip file path.
.EXAMPLE
  Compress-Folder -SourceDir C:\Logs -DestinationZip C:\Logs.zip
.NOTES
  Requires .NET’s System.IO.Compression.FileSystem.
#>
function Compress-Folder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $SourceDir,
        [Parameter(Mandatory)][string] $DestinationZip
    )
    if (-not (Test-Path $SourceDir)) {
        throw "Source folder not found: $SourceDir"
    }
    if (Test-Path $DestinationZip) { Remove-Item $DestinationZip -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($SourceDir, $DestinationZip)
    Write-Log -Level INFO -Message "Compressed '$SourceDir' → '$DestinationZip'"
}
#endregion ----------------------------------------------------------------------------------------
#region -------- Expand Zip -----------------------------------------------------------------------
<#
.SYNOPSIS
  Extracts a ZIP archive into a folder.
.DESCRIPTION
  Unpacks a .zip file into the specified output folder.
.PARAMETER ZipPath
  The .zip file to extract.
.PARAMETER OutFolder
  Destination directory to create/populate.
.EXAMPLE
  Expand-Zip -ZipPath C:\Logs.zip -OutFolder C:\Logs
.NOTES
  Requires .NET’s System.IO.Compression.FileSystem.
#>
function Expand-Zip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $ZipPath,
        [Parameter(Mandatory)][string] $OutFolder
    )
    if (-not (Test-Path $ZipPath)) {
        throw "Zip file not found: $ZipPath"
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $OutFolder)
    Write-Log -Level INFO -Message "Extracted '$ZipPath' → '$OutFolder'"
}
#endregion ----------------------------------------------------------------------------------------
#endregion ========================================================================================

#region ====== Progress & Spinner =================================================================
#region -------- Invoke With Progress -------------------------------------------------------------
<#
.SYNOPSIS
  Executes a scriptblock with a progress bar.
.DESCRIPTION
  Displays a Write-Progress bar labeled by Activity. The ScriptBlock
  you pass should accept a single parameter: a scriptblock for updating
  the progress (percent). Example:
    Invoke-WithProgress -Activity 'Copying Files' -Script {
      param($Update) 
      for ($i=1; $i -le 100; $i++) {
        Start-Sleep -Milliseconds 50
        & $Update $i
      }
    }
.PARAMETER Activity
  The text to show as the progress Activity.
.PARAMETER Script
  A scriptblock that performs work and calls the provided progress updater.
.EXAMPLE
  Invoke-WithProgress -Activity 'Processing' -Script {
    param($Update)
    1..50 | ForEach-Object {
      Start-Sleep -Milliseconds 100
      & $Update ($_ * 2)
    }
  }
.NOTES
  Outputs no objects; errors are written with Write-Error.
#>
function Invoke-With-Progress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]   $Activity,
        [Parameter(Mandatory)][scriptblock] $Script
    )
    Write-Progress -Activity $Activity -Status 'Starting...' -PercentComplete 0
    try {
        & $Script { param($pct) Write-Progress -Activity $Activity -Status 'Working' -PercentComplete $pct }
        Write-Progress -Activity $Activity -Completed
    }
    catch { Write-Log -Level ERROR -Message $_.Exception.Message }
}
#endregion ----------------------------------------------------------------------------------------
#region -------- Start Spinner --------------------------------------------------------------------
<#
.SYNOPSIS
  Starts a console spinner in the background.
.DESCRIPTION
  Launches a background job that writes a rotating spinner (|/–\).
  Use Stop-Spinner to terminate and clear the spinner.
.PARAMETER Activity
  Optional text label to show beside the spinner.
.EXAMPLE
  $job = Start-Spinner -Activity 'Waiting'
  Start-Sleep -Seconds 3
  Stop-Spinner -SpinnerJob $job
.NOTES
  Spinner writes directly to the host via Write-Host -NoNewline.
#>
function Start-Spinner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Activity
    )
    $spinnerChars = '|/-\'
    $job = Start-Job -ScriptBlock {
        param($chars,$act)
        $i = 0
        while ($true) {
            Write-Output '"`r$act $($chars[$i++ % $chars.Length])" -NoNewline'
            Start-Sleep -Milliseconds 100
        }
    } -ArgumentList ($spinnerChars.ToCharArray(), $Activity)
    return $job
}
#endregion ----------------------------------------------------------------------------------------
#region -------- Stop Spinner ---------------------------------------------------------------------
<#
.SYNOPSIS
  Stops a spinner job started with Start-Spinner.
.DESCRIPTION
  Terminates the background job, clears its output, and erases the spinner line.
.PARAMETER SpinnerJob
  The Job object returned by Start-Spinner.
.EXAMPLE
  Stop-Spinner -SpinnerJob $job
.NOTES
  Ensures the spinner line is cleared after stopping.
#>
function Stop-Spinner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Management.Automation.Job] $SpinnerJob
    )
    Stop-Job $SpinnerJob | Out-Null
    Receive-Job $SpinnerJob | Out-Null
    Remove-Job $SpinnerJob | Out-Null
    Write-Output '"`r" -NoNewline'
}
#endregion ----------------------------------------------------------------------------------------
#endregion ========================================================================================

#region ====== System & Network ===================================================================
#region -------- Test Internet Connection ---------------------------------------------------------
<#
.SYNOPSIS
  Tests Internet connectivity by pinging a URI.
.DESCRIPTION
  Attempts a simple Invoke-WebRequest to the specified URI.
  Returns $true if successful, $false otherwise.
.PARAMETER Uri
  The URL to test (default: https://www.google.com).
.OUTPUTTYPE
  System.Boolean
.EXAMPLE
  if (Test-InternetConnection) { Write-Host 'Online' } else { Write-Host 'Offline' }
.NOTES
  Uses a 5-second timeout; requires Internet access.
#>
function Test-InternetConnection {
    [CmdletBinding()]
    param(
        [string] $Uri = 'https://www.google.com'
    )
    try {
        $req = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 5
        return $true
    }
    catch {
        return $false
    }
}
#endregion ----------------------------------------------------------------------------------------
#region -------- Get System Info ------------------------------------------------------------------
<#
.SYNOPSIS
  Gathers basic system information.
.DESCRIPTION
  Queries WMI/CIM for OS, CPU, memory and disk details, then
  returns a PSCustomObject.
.OUTPUTTYPE
  System.Management.Automation.PSCustomObject
.EXAMPLE
  Get-SystemInfo | Format-List *
.NOTES
  No parameters; may require elevation for disk queries.
#>
function Get-SystemInfo {
    [CmdletBinding()]
    param()
    $os    = Get-CimInstance Win32_OperatingSystem
    $cpu   = Get-CimInstance Win32_Processor
    $disk  = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    $memGB = [math]::Round($os.TotalVisibleMemorySize/1MB,2)
    [PSCustomObject]@{
      OS          = $os.Caption
      OSVersion   = $os.Version
      CPU         = $cpu.Name
      Cores       = $cpu.NumberOfCores
      TotalMemory = "$memGB GB"
      Disks       = ($disk | ForEach-Object { "$($_.DeviceID) $([math]::Round($_.Size/1GB,2)) GB" }) -join '; '
    }
}
#endregion ----------------------------------------------------------------------------------------
#endregion ========================================================================================

#region ====== Misc Helpers =======================================================================
#region -------- Conver Size ----------------------------------------------------------------------
<#
.SYNOPSIS
  Converts a byte count into a human-readable size string.
.DESCRIPTION
  Switches on thresholds (KB, MB, GB, TB, PB) and formats
  the size to two decimals.
.PARAMETER Bytes
  The number of bytes.
.OUTPUTTYPE
  System.String
.EXAMPLE
  Convert-Size -Bytes 1048576   # "1.00 MB"
.NOTES
  1KB=1024, 1MB=1024², etc.
#>
function Convert-Size {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][double] $Bytes
    )
    switch ($Bytes) {
      {$_ -ge 1PB} { "{0:N2} PB" -f ($Bytes/1PB); break }
      {$_ -ge 1TB} { "{0:N2} TB" -f ($Bytes/1TB); break }
      {$_ -ge 1GB} { "{0:N2} GB" -f ($Bytes/1GB); break }
      {$_ -ge 1MB} { "{0:N2} MB" -f ($Bytes/1MB); break }
      {$_ -ge 1KB} { "{0:N2} KB" -f ($Bytes/1KB); break }
      default       { "{0:N2} B"  -f $Bytes }
    }
}
#endregion ----------------------------------------------------------------------------------------
#region -------- Read Input -----------------------------------------------------------------------
<#
.SYNOPSIS
  Reads a line of input, with an optional default.
.DESCRIPTION
  Prompts the user. If a Default is supplied and the user enters nothing,
  returns the Default; otherwise returns exactly what the user typed.
.PARAMETER Prompt
  The text to display as prompt.
.PARAMETER Default
  The fallback value if the user just presses Enter.
.EXAMPLE
  $name = Read-Input -Prompt 'Enter your name' -Default 'Anonymous'
.NOTES
  No colored output; suitable for scripts that need simple input.
#>
function Read-Input {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string] $Prompt,
    [string]                     $Default
  )
  if ($PSBoundParameters.ContainsKey('Default') -and $Default) {
    $resp = Read-Host "$Prompt [$Default]"
    return ([string]::IsNullOrWhiteSpace($resp) ? $Default : $resp)
  }
  else {
    return Read-Host $Prompt
  }
}
#endregion ----------------------------------------------------------------------------------------
#region -------- Pause ----------------------------------------------------------------------------
<#
.SYNOPSIS
  Pauses execution until any key is pressed.
.DESCRIPTION
  Writes a message (in dark gray) then blocks on a single keypress.
.PARAMETER Message
  The text to display (default: “Press any key to continue…”).
.EXAMPLE
  Pause -Message 'Ready to go?'
.NOTES
  Returns no objects.
#>
function Pause {
  [CmdletBinding()]
  param(
    [string] $Message = 'Press any key to continue…'
  )
  Write-Output '$Message -ForegroundColor DarkGray'
  $null = [System.Console]::ReadKey($true)
}
#endregion ----------------------------------------------------------------------------------------
#region -------- Confirm Action -------------------------------------------------------------------
<#
.SYNOPSIS
  Prompts for a yes/no confirmation.
.DESCRIPTION
  Loops until the user enters Y or N. Returns $true for Y, $false for N.
.PARAMETER Message
  The question to display (e.g. “Delete files?”).
.EXAMPLE
  if (Confirm-Action -Message 'Delete all temp files?') { … }
.NOTES
  Uses Write-Warning for invalid entries.
#>
function Confirm-Action {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string] $Message
  )
  while ($true) {
    $y = Read-Host "$Message (Y/N)"
    switch ($y.ToUpper()) {
      'Y' { return $true }
      'N' { return $false }
      default { Write-Host 'Please type Y or N.' -ForegroundColor Yellow }
    }
  }
}
#endregion ----------------------------------------------------------------------------------------
#region -------- Show Paged Text ------------------------------------------------------------------
<#
.SYNOPSIS
  Displays a text file one page at a time.
.DESCRIPTION
  Reads all lines, then pipes to Out-Host -Paging.
.PARAMETER Path
  Path to the text file to show.
.EXAMPLE
  Show-PagedText -Path '.\README.txt'
.NOTES
  If file not found, emits a warning.
#>
function Show-PagedText {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string] $Path
  )
  if (-not (Test-Path $Path)) {
    Write-Warning "File not found: $Path"
    return
  }
  Get-Content $Path | Out-Host -Paging
}
#endregion ----------------------------------------------------------------------------------------
#region -------- Ensure Directory -----------------------------------------------------------------
<#
.SYNOPSIS
  Ensures a directory exists, creating it if necessary.
.DESCRIPTION
  If the path doesn’t exist, creates it. Returns the directory’s full path.
.PARAMETER Path
  The directory path to check or create.
.EXAMPLE
  $out = Ensure-Directory -Path '.\Logs'
.NOTES
  Creates only the final leaf; parent dirs are created as needed.
#>
function Ensure-Directory {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string] $Path
  )
  if (-not (Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
  return (Get-Item $Path).FullName
}
#endregion ----------------------------------------------------------------------------------------
#region -------- Resolve AbsolutePath -------------------------------------------------------------
<#
.SYNOPSIS
  Resolves a path to its absolute provider path.
.DESCRIPTION
  Uses Resolve-Path to canonicalize the input. Throws if resolution fails.
.PARAMETER Path
  The path to resolve (file or directory).
.EXAMPLE
  $full = Resolve-AbsolutePath -Path '.\foo.txt'
.NOTES
  Returns the PSProvider path; not the raw Win32 path.
#>
function Resolve-AbsolutePath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string] $Path
  )
  return (Resolve-Path $Path).ProviderPath
}
#endregion ----------------------------------------------------------------------------------------
#endregion ========================================================================================

#region ====== Get Script Base Name ===============================================================
<#
.SYNOPSIS
  Gets the base name (no extension) of the running script.
.DESCRIPTION
  If the script was dot-sourced or run as a file, uses its file path;
  otherwise falls back to the invocation name.
.EXAMPLE
  $base = Get-ScriptBaseName
.NOTES
  Always returns a string.
#>
function Get-ScriptBaseName {
    if ($MyInvocation.MyCommand.Path) {
        return [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)
    }
    else {
        return [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
    }
}
#endregion ========================================================================================

#region ====== Get Script Folder ==================================================================
<#
.SYNOPSIS
  Gets the folder containing the running script.
.DESCRIPTION
  Returns the directory of the script file, or the current working directory
  if invocation path is unavailable.
.EXAMPLE
  $dir = Get-ScriptFolder
.NOTES
  Useful for resolving sibling script paths.
#>
function Get-ScriptFolder {
    if ($MyInvocation.MyCommand.Path) {
        return [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
    }
    else {
        return (Get-Location).Path
    }
}
#endregion ========================================================================================

#region ====== Get Script Full Path ===============================================================
<#
.SYNOPSIS
  Returns the full file path of the running script.
.DESCRIPTION
  If the script was invoked from a file, returns its absolute path.
  Otherwise, constructs a path from the current working directory
  and the invocation name.
.OUTPUTTYPE
  System.String
.EXAMPLE
  PS> Get-ScriptFullPath
  C:\Scripts\MyModule\MyScript.ps1
.NOTES
  Useful for modules or scripts that need to locate their own folder.
#>
function Get-ScriptFullPath {
    if ($MyInvocation.MyCommand.Path) {
        return $MyInvocation.MyCommand.Path
    }
    else {
        $name = $MyInvocation.MyCommand.Name
        $folder = (Get-Location).Path
        return Join-Path -Path $folder -ChildPath $name
    }
}
#endregion ========================================================================================

#region ====== Read Global Config =================================================================
<#
.SYNOPSIS
  Loads a JSON configuration file into a PS object.
.DESCRIPTION
  Reads the file at ConfigPath, parses its JSON content,
  and returns the resulting object. If the file is missing
  or contains invalid JSON, writes a warning or error and
  returns $null.
.PARAMETER ConfigPath
  Path to the JSON configuration file.
.OUTPUTTYPE
  System.Management.Automation.PSCustomObject
.EXAMPLE
  $cfg = Read-GlobalConfig -ConfigPath '.\config.json'
.NOTES
  Does not throw on missing file—returns $null.
#>
function Read-GlobalConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    if (Test-Path -Path $ConfigPath) {
        try {
            $jsonContent = Get-Content -Path $ConfigPath -Raw
            return $jsonContent | ConvertFrom-Json
        }
        catch {
            Write-Log -Level "ERROR" -Message "Failed to parse config file at ${ConfigPath}: $_"
            return $null
        }
    }
    else {
        Write-Log -Level "WARN" -Message "Config file not found at $ConfigPath"
        return $null
    }
}
#endregion ========================================================================================

#region ====== Export Module Member ===============================================================
# Public API
$PublicFunctions = @(
    'Get-ScriptBaseName'
    'Get-ScriptFolder'
    'Get-ScriptFullPath'
    'Read-GlobalConfig'
    'Write-Log'
    'Get-Json'
    'Save-Json'
    'Measure-ExecutionTime'
    'Compress-Folder'
    'Expand-Zip'
    'Invoke-With-Progress'
    'Start-Spinner'
    'Stop-Spinner'
    'Test-InternetConnection'
    'Get-SystemInfo'
    'Convert-Size'
    'Read-Input'
    'Pause'
    'Confirm-Action'
    'Show-PagedText'
    'Ensure-Directory'
    'Resolve-AbsolutePath'
)

Export-ModuleMember -Function $PublicFunctions

#endregion ========================================================================================
