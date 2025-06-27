function Load-Translations {
    param([string]$Lang, [string]$BasePath)
    $file = Join-Path $BasePath "lang\$Lang.json"
    if (Test-Path $file) {
        return (Get-Content $file -Raw) | ConvertFrom-Json
    }
    return @{}
}

function Get-LocalizedString {
    param([string]$Key)
    if ($Global:Translations.ContainsKey($Key)) { return $Global:Translations[$Key] }
    return $Key
}

Export-ModuleMember Load-Translations, Get-LocalizedString
