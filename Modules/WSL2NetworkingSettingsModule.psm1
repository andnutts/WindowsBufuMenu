# Modules/WSL2NetworkingSettingsModule.psm1


<#
.SYNOPSIS
  Retrieves the host’s WSL2 virtual network adapters.
.DESCRIPTION
  Filters Get-NetAdapter for Hyper-V vEthernet adapters used by WSL2.
.OUTPUTTYPE
  Microsoft.Management.Infrastructure.CimInstance
.EXAMPLE
  Get-WSL2NetworkAdapter | Format-Table Name, InterfaceDescription
#>
function Get-WSL2NetworkAdapter {
  [CmdletBinding()]
  param()
  Get-NetAdapter |
    Where-Object InterfaceDescription -Match 'Hyper-V Virtual Ethernet Adapter' |
    Where-Object Name               -Like 'vEthernet*'
}

<#
.SYNOPSIS
  Returns the IPv4 default gateway for WSL2 networking.
.DESCRIPTION
  Finds the first WSL2 virtual adapter and queries its IPv4 default gateway.
.OUTPUTTYPE
  System.String
.EXAMPLE
  $gw = Get-WSL2Gateway
#>
function Get-WSL2Gateway {
  [CmdletBinding()]
  param()
  $nic = Get-WSL2NetworkAdapter
  if (-not $nic) {
    Write-Warning 'WSL2 virtual adapter not found.'
    return
  }
  (Get-NetIPConfiguration -InterfaceIndex $nic.ifIndex).IPv4DefaultGateway.NextHop
}

<#
.SYNOPSIS
  Retrieves the IPv4 address of a WSL2 distro’s eth0 interface.
.DESCRIPTION
  Uses wsl.exe to run `ip -4 addr show eth0` in the specified distribution
  and parses the first “inet” address.
.PARAMETER DistributionName
  The name of the WSL2 distro (e.g., “Ubuntu-20.04”).
.OUTPUTTYPE
  System.String
.EXAMPLE
  Get-WSL2IPAddress -DistributionName 'Ubuntu-20.04'
.NOTES
  Requires PowerShell 7+ for wsl.exe piping.
#>
function Get-WSL2IPAddress {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string] $DistributionName
  )
  # requires PowerShell 7+; uses wsl.exe to grab eth0 IPv4
  $out = wsl.exe -d $DistributionName -- ip -4 addr show eth0
  if ($out -match 'inet\s+([\d\.]+)') { return $Matches[1] }
}

<#
.SYNOPSIS
  Restarts WSL2 networking by shutting down WSL and restarting its service.
.DESCRIPTION
  Shuts down all WSL2 distributions, then restarts LxssManager Windows service.
.OUTPUTTYPE
  None
.EXAMPLE
  Restart-WSL2Networking
.NOTES
  Requires elevated privileges to restart service.
#>
function Restart-WSL2Networking {
  [CmdletBinding()]
  param()
  Write-Output ''Shutting down WSL2…' -ForegroundColor Cyan'
  wsl.exe --shutdown
  Start-Sleep -Seconds 2
  Write-Output ''Restarting LxssManager service…' -ForegroundColor Cyan'
  Restart-Service LxssManager -ErrorAction SilentlyContinue
  Write-Output ''WSL2 networking restarted.' -ForegroundColor Green'
}

<#
.SYNOPSIS
  Adds an entry to the Windows hosts file for a WSL2 distro.
.DESCRIPTION
  Retrieves the distro’s eth0 IP and appends a “IP hostname” line to hosts.
.PARAMETER HostName
  The DNS name to map to the distro IP.
.PARAMETER Distro
  The WSL2 distribution name.
.EXAMPLE
  Add-WSL2HostsEntry -HostName myubuntu.local -Distro Ubuntu-20.04
.NOTES
  Requires elevation to modify hosts file.
#>
function Add-WSL2HostsEntry {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][string] $HostName,
    [Parameter(Mandatory)][string] $Distro
  )
  $ip = Get-WSL2IPAddress -DistributionName $Distro
  if (-not $ip) {
    Write-Warning "Could not determine IP for distro '$Distro'."
    return
  }
  $hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
  if (-not (Test-Path $hosts)) {
    Write-Warning "Cannot find hosts file at $hosts"
    return
  }
  $entry = "$ip`t$HostName"
  if ((Get-Content $hosts) -match [regex]::Escape($HostName)) {
    Write-Warning "An entry for '$HostName' already exists."
    return
  }
  if ($PSCmdlet.ShouldProcess($hosts, "Add $entry")) {
    Add-Content -Path $hosts -Value $entry
    Write-Output '"Added hosts entry: $entry" -ForegroundColor Green'
  }
}

<#
.SYNOPSIS
  Removes entries from Windows hosts file matching a WSL2 hostname.
.DESCRIPTION
  Filters out any lines mapping the specified hostname from the hosts file
  and rewrites it.
.PARAMETER HostName
  The DNS name whose entries should be removed.
.EXAMPLE
  Remove-WSL2HostsEntry -HostName myubuntu.local
.NOTES
  Requires elevation to modify hosts file.
#>
function Remove-WSL2HostsEntry {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][string] $HostName
  )
  $hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
  if (-not (Test-Path $hosts)) {
    Write-Warning "Cannot find hosts file at $hosts"
    return
  }
  $lines = Get-Content $hosts
  $filtered = $lines | Where-Object { $_ -notmatch "^\s*[\d\.]+\s+$HostName(\s|$)" }
  if ($PSCmdlet.ShouldProcess($hosts, "Remove entries for $HostName")) {
    $filtered | Set-Content $hosts
    Write-Output '"Removed entries for '$HostName'." -ForegroundColor Green'
  }
}

# Public API for WSL2 networking helpers
$PublicFunctions = @(
    'Get-WSL2NetworkAdapter'
    'Get-WSL2Gateway'
    'Get-WSL2IPAddress'
    'Restart-WSL2Networking'
    'Add-WSL2HostsEntry'
    'Remove-WSL2HostsEntry'
)

Export-ModuleMember -Function $PublicFunctions
