# Modules/DynamicModuleLoader.psm1
<#
.SYNOPSIS
  Dynamically imports a related module and returns its exported functions.
.DESCRIPTION
  Given the current script path (defaulting to this .ps1), this function:
    • Derives a base name by stripping “_Menu” from the file name
    • Constructs a module file name (“<BaseName>Module.psm1” in ../Modules)
    • Imports the module if not already loaded
    • Returns a sorted list of its exported function commands

.PARAMETER ScriptPath
  Path to the calling script. If omitted, uses the path of the invoking command.

.OUTPUTTYPE
  System.Management.Automation.CommandInfo[]

.EXAMPLE
  # In WSL2_Menu.ps1:
  $functions = Get-ModuleFunctionsFromScriptName
  foreach ($fn in $functions) { Write-Host $fn.Name }

.NOTES
  Assumes your modules are located in a “Modules” sibling folder.
  Uses Resolve-Path to handle relative paths and silences errors.
#>
[CmdletBinding()]
[OutputType([System.Management.Automation.CommandInfo[]])]
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER ScriptPath
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-ModuleFunctionsFromScriptName {
    param(
        [string]$ScriptPath = $MyInvocation.MyCommand.Path
    )

    if (-not $ScriptPath) {
        Write-Warning 'Unable to determine script path.'
        return @()
    }

    # Determine base module name
    $baseName   = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath) -replace '_Menu$',''
    $moduleName = "${baseName}Module"
    $moduleFile = Join-Path -Path (Split-Path $ScriptPath) -ChildPath "..\Modules\$moduleName.psm1"

    try {
        $resolved = Resolve-Path -Path $moduleFile -ErrorAction Stop
    }
    catch {
        Write-Warning "Module file not found: $moduleFile"
        return @()
    }

    if (-not (Get-Module -Name $moduleName)) {
        try {
            Import-Module -Name $resolved.Path -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to import module '$moduleName': $($_.Exception.Message)"
            return @()
        }
    }

    # Return its exported functions
    return Get-Command -Module $moduleName -CommandType Function | Sort-Object Name
}

#───────────────────────────────────────────────────────────────────────────────
# Export public API
Export-ModuleMember -Function Get-ModuleFunctionsFromScriptName
```