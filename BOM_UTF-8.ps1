# BOM_UTF-8.ps1
Get-ChildItem .\*.ps1,*.psm1 -Recurse |
  ForEach-Object {
    $content = Get-Content -Raw -LiteralPath $_.FullName
    # -Encoding utf8BOM writes a BOM
    $content | Out-File -LiteralPath $_.FullName -Encoding utf8BOM
  }
