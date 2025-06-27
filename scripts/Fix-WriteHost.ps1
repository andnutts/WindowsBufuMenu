# Fix-WriteHost.ps1
<#
.SYNOPSIS
  Bulk-replace Write-Host with Write-Information in a script/module.
.DESCRIPTION
  You can exclude UI-rendering functions by name so their colored
  console output stays intact.
.PARAMETER SourcePath
  Path to your original .ps1/.psm1 file.
.PARAMETER DestPath
  (Optional) Where to write the converted file. Defaults to
  <Source>-Converted.psm1.
.PARAMETER ExcludeFunctions
  Names of functions to skip (e.g. your menu-renderers).
.EXAMPLE
  .\Convert-WriteHost.ps1 `
    -SourcePath .\MenuLibrary.psm1 `
    -ExcludeFunctions Write-Centered,Show-Menu,Show-Help
#>
param(
  [Parameter(Mandatory)] [string]   $SourcePath,
  [string]                         $DestPath       = ($(Split-Path $SourcePath -LeafBase) + '-Converted.psm1'),
  [string[]]                       $ExcludeFunctions = @(
    'Write-Centered','Show-CenteredInfo','Update-CenteredOutput',
    'Show-Menu','Show-Help','Show-PagedText','Show-ProgressBar','Pause'
  )
)

# Read & split into lines
$lines = Get-Content -LiteralPath $SourcePath

# We'll keep a stack of [FunctionName, BraceBalance]
$funcStack = @()
$outLines   = @()

foreach ($line in $lines) {
  # Detect function declaration
  if ($line -match '^\s*function\s+([^\s\{\(]+)') {
    $funcName = $matches[1]
    $funcStack += [pscustomobject]@{ Name = $funcName; Balance = 0 }
  }

  # Track braces to know when we exit a function
  if ($funcStack.Count -gt 0) {
    $opens  = ([regex]::Matches($line,'\{')).Count
    $closes = ([regex]::Matches($line,'\}')).Count
    $funcStack[-1].Balance += $opens - $closes

    if ($funcStack[-1].Balance -le 0) {
      # we've closed the function block
      $funcStack = $funcStack[0..($funcStack.Count - 2)]
    }
  }

  # Current function in?  Might be $null if we're at top level
  $currentFunc = if ($funcStack) { $funcStack[-1].Name } else { $null }

  if ($currentFunc -and $ExcludeFunctions -contains $currentFunc) {
    # leave UI-only functions untouched
    $outLines += $line
  }
  else {
    # do the global swap
    $outLines += $line -replace '(?<!\w)Write-Host\b','Write-Information'
  }
}

# Write out
$outLines | Set-Content -LiteralPath $DestPath -Encoding UTF8
Write-Host "✔ Converted file written to: $DestPath"
