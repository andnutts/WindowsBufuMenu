# Modules/Config.psm1
function Load-GlobalConfig {
    [CmdletBinding()]
    param(
        [string] $ConfigPath = "$PSScriptRoot/../config.json"
    )
    if (-not (Test-Path $ConfigPath)) {
        Throw "Global config not found: $ConfigPath"
    }
    $json = Get-Content $ConfigPath -Raw
    return $json | ConvertFrom-Json
}

Export-ModuleMember -Function Load-GlobalConfig
