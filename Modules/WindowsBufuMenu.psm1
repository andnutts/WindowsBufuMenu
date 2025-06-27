# Modules\WindowsBufuMenu.psm1
# —————————————————————————————————————————————————————
# Dot-source every .ps1 in your project’s Menu_Scripts
$menuFolder = Join-Path $PSScriptRoot '..\..\Menu_Scripts'
Get-ChildItem $menuFolder ‑Filter '*.ps1' | ForEach-Object {
  . $_.FullName
}

# Whitelist whatever functions you want published
Export-ModuleMember -Function *
