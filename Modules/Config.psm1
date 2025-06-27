<#
.SYNOPSIS
  Loads a global JSON configuration file into a PowerShell object.

.DESCRIPTION
  Reads the specified JSON file (defaults to ../config.json relative to this module),
  deserializes it with ConvertFrom-Json, and returns the resulting PSCustomObject.
  Throws an error if the file is missing or the JSON is invalid.

.PARAMETER ConfigPath
  Path to the JSON configuration file. Defaults to "$PSScriptRoot/../config.json".

.OUTPUTTYPE
  System.Management.Automation.PSCustomObject

.EXAMPLE
  # In your module’s top-level scope:
  $Global:Config = Import-GlobalConfig

.NOTES
  • Requires that the file exist and contain valid JSON.  
  • Errors writing are caught and re-thrown as terminating errors.  
  • Designed for use in a module’s initialization sequence.
#>
[CmdletBinding()]
[OutputType([PSCustomObject])]
function Import-GlobalConfig {
    param(
        [Parameter(Position=0)]
        [string]$ConfigPath = "$PSScriptRoot/../config.json"
    )

    if (-not (Test-Path -Path $ConfigPath)) {
        Throw "Global config not found: $ConfigPath"
    }

    try {
        $raw = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop
        return $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Throw "Failed to load or parse global config at '$ConfigPath': $($_.Exception.Message)"
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Public API
$PublicFunctions = @(
    'Import-GlobalConfig'
)

Export-ModuleMember -Function $PublicFunctions
#───────────────────────────────────────────────────────────────────────────────
```