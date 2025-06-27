<#
.SYNOPSIS
  Loads a JSON translation file for a given language.
.DESCRIPTION
  Reads the file at “$BasePath/lang\<Lang>.json”, parses its JSON,
  and stores the resulting key/value pairs in a module‐private 
  hashtable `$script:Translations` for later retrieval.
.PARAMETER Lang
  Language code (e.g. “en”, “fr”).
.PARAMETER BasePath
  Root folder containing the “lang” subdirectory.
.OUTPUTTYPE
  System.Collections.Hashtable
.EXAMPLE
  # Load English translations from your module folder
  Load-Translations -Lang 'en' -BasePath $PSScriptRoot
.NOTES
  If the file is missing or invalid JSON, returns an empty hashtable.
#>
[CmdletBinding()]
[OutputType([hashtable])]
function Load-Translations {
    param(
        [Parameter(Mandatory)][string] $Lang,
        [Parameter(Mandatory)][string] $BasePath
    )

    $file = Join-Path -Path $BasePath -ChildPath "lang\$Lang.json"
    if (-not (Test-Path $file)) {
        Write-Warning "Translation file not found: $file"
        return @{}
    }

    try {
        $json = Get-Content -Path $file -Raw -ErrorAction Stop |
                ConvertFrom-Json -ErrorAction Stop

        # Build a pure hashtable for fast lookups
        $script:Translations = @{}
        foreach ($prop in $json.PSObject.Properties) {
            $script:Translations[$prop.Name] = $prop.Value
        }

        Write-Verbose "Loaded $($script:Translations.Count) translations for '$Lang'."
        return $script:Translations
    }
    catch {
        Write-Error "Failed to load translations from '$file': $($_.Exception.Message)"
        return @{}
    }
}


#───────────────────────────────────────────────────────────────────────────────
<#
.SYNOPSIS
  Retrieves a localized string by key.
.DESCRIPTION
  Looks up `$Key` in the hashtable `$script:Translations`. 
  If found, returns the translated value; otherwise falls back 
  to returning the key itself.
.PARAMETER Key
  The translation key to look up.
.OUTPUTTYPE
  System.String
.EXAMPLE
  # After calling Load-Translations ...
  Get-LocalizedString -Key 'WelcomeMessage'
.NOTES
  Make sure to call Load-Translations first.
#>
[CmdletBinding()]
[OutputType([string])]
function Get-LocalizedString {
    param(
        [Parameter(Mandatory)][string] $Key
    )

    if ($script:Translations -and $script:Translations.ContainsKey($Key)) {
        return $script:Translations[$Key]
    }
    Write-Verbose "Translation for key '$Key' not found; using key as fallback."
    return $Key
}


#───────────────────────────────────────────────────────────────────────────────
# Publicly exposed functions
Export-ModuleMember -Function Load-Translations, Get-LocalizedString
```