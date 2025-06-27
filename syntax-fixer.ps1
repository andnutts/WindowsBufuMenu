Get-ChildItem -Path .\Menus, .\Modules -Recurse -File |
  Where-Object { $_.Extension -in '.ps1','.psm1' } |
  ForEach-Object {
    try { . $_.FullName }
    catch { Write-Error "Syntax error in $($_.FullName): $($_.Exception.Message)" }
  }
