# scripts/WSL2_HostNames.ps1

# Get the list of installed WSL2 distributions
#$installedDistros = wsl --list --verbose | Select-String -Pattern "^[^ ]+ +[^ ]+ +(?<DistroName>[^ ]+)"
# Output the list of installed distributions
#Write-Output $installedDistros
#endregion ========================================================================================

#region ====== Define an array of WSL2 distribution names =========================================
$wsl2Distros = @("Ubuntu", "Ubuntu-22.04", "Debian", "openSUSE-42")
#endregion ========================================================================================

#region ====== Function to get the hostname for a WSL2 distribution ===============================
function Get-WSL2Hostname {
    param (
        [string]$distroName
    )

    try {
        # Execute the hostname command within the WSL2 distribution
        $hostname = wsl -d $distroName hostname
        Write-Output "${distroName}: $hostname"
    } catch {
        Write-Output "Failed to get hostname for $distroName"
    }
}
#endregion ========================================================================================

#region ====== Loop through each WSL2 distribution and get its hostname ===========================
foreach ($distro in $wsl2Distros) {
    Get-WSL2Hostname -distroName $distro
}
#endregion ========================================================================================