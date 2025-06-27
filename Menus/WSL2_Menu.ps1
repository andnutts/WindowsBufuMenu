# Menus/WSL2_Menu.ps1

#region ====== Load Modules =======================================================================
Import-Module "$PSScriptRoot/../Modules/MenuLibrary.psm1"  # your menu engine
Import-Module "$PSScriptRoot/../Modules/WSL2Module.psm1"   # our functions

#endregion ========================================================================================
#region ====== Dynamic Menu Generator =============================================================
# 1) discover all exported functions in WSL2Module
$funcs = Get-Command -Module WSL2Module -CommandType Function |
         Sort-Object Name

# 2) build menu options
$opts = foreach ($f in $funcs) {
    # turn FooBarBaz into "Foo Bar Baz"
    $label = ($f.Name -replace '([a-z])([A-Z])','$1 $2')

    # if function has parameters, build a SB that prompts for each one
    if ($f.Parameters.Count -gt 0) {
        $paramPrompts = $f.Parameters.Keys | ForEach-Object {
            "`$$_ = Read-Input -Prompt 'Enter $_ for $($f.Name)'"
        } -join "`n"

        $paramArray = '$params = @(' + (
            $f.Parameters.Keys | ForEach-Object { "`$$_" }
        ) -join ', ' + ')'

        $sbText = @"
$paramPrompts
$paramArray
& $($f.Name) @params
"@

        $sb = [scriptblock]::Create($sbText)
    }
    else {
        # no parameters ⇒ just invoke
        $sb = [scriptblock]::Create("& $($f.Name)")
    }

    [PSCustomObject]@{
        Label = $label
        Value = $sb
    }
}

# 3) drive the menu
while ($true) {
    $choice = Show-Menu -Title 'WSL2 Configuration' -Options $opts

    switch ($choice) {
      'ESC'  { Exit }
      'BACK' { break }
      # any scriptblock => invoke then pause
      { $_ -is [scriptblock] } {
        & $choice
        Pause
      }
      default { }
    }
}

#endregion ========================================================================================