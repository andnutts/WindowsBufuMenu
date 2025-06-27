# Modules/WSL2Module.psm1


function Install-Ubuntu2204 {
    <#
    .SYNOPSIS
      Installs Ubuntu 22.04 under WSL2
    #>
    wsl --install -d Ubuntu-22.04
}

function List-WSLDistros {
    <#
    .SYNOPSIS
      Lists all installed WSL distributions
    #>
    wsl --list --verbose
}

function Set-DefaultWSLDistro {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Distro
    )
    <#
    .SYNOPSIS
      Sets the default WSL distro
    #>
    wsl --set-default $Distro
}

#region 

Export-ModuleMember -Function Install-Ubuntu2204, List-WSLDistros, Set-DefaultWSLDistro
