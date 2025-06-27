# scripts/WSL2_HostInfo.ps1

#region ====== Get the list of installed WSL2 distributions =======================================
$installedDistros = wsl --list --quiet
Write-Output $installedDistros
#endregion ========================================================================================

#region ====== Function to get the IP address and hostname for a WSL2 distribution ================
function Get-WSL2Details {
    param (
        [string]$distroName
    )

    try {
        # Execute commands within the WSL2 distribution to get the IP address and hostname
        $ipAddress = wsl -d $distroName ip addr show eth0 | Select-String -Pattern "inet " | ForEach-Object { $_.ToString().Split(" ")[5].Split("/")[0] }
        $hostname = wsl -d $distroName hostname

        [PSCustomObject]@{
            DistroName = $distroName
            Hostname   = $hostname.Trim()
            IPAddress  = $ipAddress.Trim()
        }
    } catch {
        [PSCustomObject]@{
            DistroName = $distroName
            Hostname   = "Failed to get hostname"
            IPAddress  = "Failed to get IP address"
        }
    }
}
#endregion ========================================================================================

#region ====== Get the details for all installed WSL2 distributions ===============================
$wsl2Details = $installedDistros | ForEach-Object {
    Get-WSL2Details -distroName $_
}
#endregion ========================================================================================

#region ====== Output the details in a table format ===============================================
$wsl2Details | Format-Table -AutoSize
#endregion ========================================================================================