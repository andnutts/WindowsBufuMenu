<#
.SYNOPSIS
  Imports all plugin modules (.psm1) from a specified directory.

.DESCRIPTION
  Recursively scans the given PluginsPath for PowerShell module files
  (*.psm1) and imports each one with Force. Useful for dynamically
  loading extensions or plugins.

.PARAMETER PluginsPath
  The directory containing plugin .psm1 files. Must exist.

.EXAMPLE
  Import-Plugins -PluginsPath "C:\MyApp\Plugins"

.NOTES
  • Supports -Verbose for detailed load messages.  
  • Throws an error if the path is invalid or an import fails.
#>
[CmdletBinding()]
[OutputType([void])]
function Import-Plugins {
    [Alias('Import-Plugin')]
    param(
        [Parameter(Mandatory, Position=0)]
        [ValidateScript({ Test-Path $_ -PathType 'Container' })]
        [string]$PluginsPath
    )

    Write-Verbose "Scanning for plugin modules in '$PluginsPath'..."
    try {
        Get-ChildItem -Path $PluginsPath -Filter '*.psm1' -File -Recurse |
        ForEach-Object {
            Write-Verbose "Importing plugin module: $($_.FullName)"
            Import-Module -Name $_.FullName -Force -Scope Global
        }
    }
    catch {
        Write-Error "Failed to import plugins from '$PluginsPath': $($_.Exception.Message)"
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Public API
Export-ModuleMember -Function Import-Plugins
```