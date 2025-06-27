<#
.SYNOPSIS
  Scaffold a “rock-solid” WindowsBufuMenu project layout.

.DESCRIPTION
  Creates directories, placeholder files, module manifest, CI/workflow stubs, test folder,
  docs folder, and a run-menu entry script.

.PARAMETER ProjectRoot
  The root folder for your project. Defaults to current directory.

.PARAMETER ModuleName
  The name of the PowerShell module to create under Modules\.

.PARAMETER ModuleVersion
  Initial semantic version for your module manifest.

.EXAMPLE
  .\Init-WindowsBufuMenuProject.ps1 -ProjectRoot C:\code\windows_bufu_menu
#>
param(
    [string]$ProjectRoot   = (Get-Location).Path,
    [string]$ModuleName    = 'MenuLibrary',
    [string]$ModuleVersion = '1.0.0'
)

Set-StrictMode -Version Latest

# 1. Define directories to create
$dirs = @(
    '.github/workflows',
    'docs',
    "Modules\$ModuleName",
    'Menu_Scripts',
    'tests',
    'scripts'
)

# 2. Create folder hierarchy
foreach ($rel in $dirs) {
    $full = Join-Path $ProjectRoot $rel
    if (-not (Test-Path $full)) {
        New-Item -Path $full -ItemType Directory -Force | Out-Null
        Write-Host "Created: $rel"
    }
}

# 3. Create root‐level files if missing
$rootFiles = @{
    '.gitignore'     = "# Ignore PowerShell temp files`n*.log`n*.cache`n";
    '.editorconfig'  = "[*]`nindent_style = space`nindent_size = 4`n";
    'README.md'      = "# windows_bufu_menu`nA BuFu-style Windows menu module.`n";
    'LICENSE'        = "MIT License`n<year> <Your Name>";
    'CHANGELOG.md'   = "# Changelog`nAll notable changes to this project will be documented here.";
    'run-menu.ps1'   = @"
<#
.SYNOPSIS
  Entry point for windows_bufu_menu.
#>
Param()
\$root = Split-Path -Parent \$MyInvocation.MyCommand.Definition
\$mod  = Join-Path \$root "Modules\$ModuleName\$ModuleName.psd1"
Import-Module \$mod -Force -Verbose
# Invoke your top-level menu function:
Show-BufuMenu
"@
}

foreach ($file in $rootFiles.GetEnumerator()) {
    $path = Join-Path $ProjectRoot $file.Key
    if (-not (Test-Path $path)) {
        $file.Value | Out-File -FilePath $path -Encoding UTF8
        Write-Host "Created: $($file.Key)"
    }
}

# 4. Scaffold the module files
$modPath = Join-Path $ProjectRoot "Modules\$ModuleName"
$psm1 = Join-Path $modPath "$ModuleName.psm1"
$psd1 = Join-Path $modPath "$ModuleName.psd1"

if (-not (Test-Path $psm1)) {
    @"
<#  
  $ModuleName module entry point  
#>

# Dot-source all menu scripts
\$menuFolder = Join-Path \$PSScriptRoot '../../Menu_Scripts'
Get-ChildItem \$menuFolder -Filter '*.ps1' | ForEach-Object { . \$_.FullName }

# Export everything; refine to explicit list if you like
Export-ModuleMember -Function *
"@ | Out-File -FilePath $psm1 -Encoding UTF8
    Write-Host "Created: Modules\$ModuleName\$ModuleName.psm1"
}

if (-not (Test-Path $psd1)) {
    New-ModuleManifest `
      -Path        $psd1 `
      -RootModule  "$ModuleName.psm1" `
      -ModuleVersion $ModuleVersion `
      -Author      'Your Name' `
      -Description "$ModuleName core functions" `
      -FunctionsToExport '*' `
      | Out-Null
    Write-Host "Created: Modules\$ModuleName\$ModuleName.psd1"
}

# 5. Create CI and Release workflow stubs
$ciYaml = @"
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup PowerShell
        uses: pwsh/setup-pwsh@v2
      - name: Install Dependencies
        run: Install-Module -Name Pester -Force -Scope CurrentUser
      - name: Run Pester Tests
        run: Invoke-Pester -Path tests -Verbose
      - name: Lint with PSScriptAnalyzer
        run: Invoke-ScriptAnalyzer -Path Modules -Recurse -Severity Warning
"@
$releaseYaml = @"
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  publish:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup PowerShell
        uses: pwsh/setup-pwsh@v2
      - name: Publish Module
        run: |
          Install-Module -Name PowerShellGet -Force -Scope CurrentUser
          Publish-Module -Path Modules\$ModuleName -NuGetApiKey '${{ secrets.PSGalleryKey }}'
"@

$ciPath      = Join-Path $ProjectRoot '.github\workflows\ci.yml'
$releasePath = Join-Path $ProjectRoot '.github\workflows\release.yml'

if (-not (Test-Path $ciPath)) {
    $ciYaml | Out-File -FilePath $ciPath -Encoding UTF8
    Write-Host "Created: .github/workflows/ci.yml"
}
if (-not (Test-Path $releasePath)) {
    $releaseYaml | Out-File -FilePath $releasePath -Encoding UTF8
    Write-Host "Created: .github/workflows/release.yml"
}

Write-Host "Scaffold complete! Review and customize placeholders (Author, LICENSE, scripts)."
