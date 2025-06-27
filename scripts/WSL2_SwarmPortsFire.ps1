# scripts/WSL2_SwarmPortsFire.ps1

#region ====== File path to save the log details ==================================================
$pcName = $env:COMPUTERNAME
$dispGroup = "WSL2"
$scriptDir = "$env:USERPROFILE\scripts"
$logFile = "$scriptDir\logs\${pcName}_WSL2 Swarm_rules.log"
#endregion ========================================================================================

#region ====== Function to log messages with timestamp and computer name ==========================
function Log-Message {
  param (
      [string]$message
  )
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $logEntry = "$timestamp [$computerName] : $message"
  $logEntry | Out-File -FilePath $logFile -Encoding UTF8 -Append
  Write-Output $logEntry
}
#endregion ========================================================================================

#region ====== Ports required for Docker Swarm ====================================================
$tcpPorts = @(2376, 2377, 7946)
$udpPorts = @(4789, 7946)
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}
#endregion ========================================================================================

#region ====== Listen address =====================================================================
$listenAddress = '0.0.0.0'
#endregion ========================================================================================

#region ====== Get the WSL2 IP address ============================================================
$wsl2Ip = wsl hostname -I | ForEach-Object { $_.Trim() } | ForEach-Object { $_.Split(" ")[0] }
$remoteport = ((wsl hostname -I) -split " ")[0]
$found = $remoteport -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
if ($found) {
    $remoteport = $matches[0]
} else {
    Write-Output "The Script Exited, the IP address of WSL 2 cannot be found"
    Log-Message "The Script Exited, the IP address of WSL 2 cannot be found"
    exit
}
# Reset port proxy if needed (uncomment the line below)
# Invoke-Expression "netsh interface portproxy reset"
#endregion ========================================================================================

#region ====== Configure port proxy and firewall rules for each TCP port ==========================
foreach ($port in $tcpPorts) {
  Invoke-Expression "netsh interface portproxy delete v4tov4 listenport=$port listenaddress=$listenAddress"
  Invoke-Expression "netsh interface portproxy add v4tov4 listenport=$port listenaddress=$listenAddress connectport=$port connectaddress=$remoteport"
  $firewallRuleName = "Swarm TCP $port*"

  # Delete old firewall rule
  Remove-NetFirewallRule -DisplayName "Swarm TCP $port" -ErrorAction SilentlyContinue
  Remove-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue

  # Add new inbound and outbound firewall rules
  $firewallRuleNameInbound = "Swarm TCP $port(Inbound)"
  $firewallRuleNameOutbound = "Swarm TCP $port(Outbound)"
  New-NetFirewallRule -DisplayName $firewallRuleNameInbound -Group $dispGroup -Direction Inbound -Action Allow -Protocol TCP `
      -LocalPort $port -Description "Inbound Rule for Docker Swarm TCP"
  New-NetFirewallRule -DisplayName $firewallRuleNameOutbound -Group $dispGroup -Direction Outbound -Action Allow -Protocol TCP `
      -LocalPort $port -Description "Outbound Rule for Docker Swarm TCP"

  Write-Output "Configured port proxy and firewall rules for TCP port $port"
  Log-Message "Configured port proxy and firewall rules for TCP port $port"
}
#endregion ========================================================================================

#region ====== Configure port proxy and firewall rules for each UDP port ==========================
foreach ($port in $udpPorts) {
  Invoke-Expression "netsh interface portproxy delete v4tov4 listenport=$port listenaddress=$listenAddress"
  Invoke-Expression "netsh interface portproxy add v4tov4 listenport=$port listenaddress=$listenAddress connectport=$port connectaddress=$remoteport"
  $firewallRuleName = "Swarm UDP $port*"
  # Delete old firewall rule
  Remove-NetFirewallRule -DisplayName "Swarm UDP $port" -ErrorAction SilentlyContinue

  # Add new inbound and outbound firewall rules
  $firewallRuleNameInbound = "Swarm UDP $port(Inbound)"
  $firewallRuleNameOutbound = "Swarm UDP $port(Outbound)"
  New-NetFirewallRule -DisplayName $firewallRuleNameInbound -Group $dispGroup -Direction Inbound -Action Allow -Protocol UDP `
      -LocalPort $port -Description "Inbound Rule for Docker Swarm UDP"
  New-NetFirewallRule -DisplayName $firewallRuleNameOutbound -Group $dispGroup -Direction Outbound -Action Allow -Protocol UDP `
      -LocalPort $port -Description "Outbound Rule for Docker Swarm UDP"

  Write-Output "Configured port proxy and firewall rules for UDP port $port"
  Log-Message "Configured port proxy and firewall rules for UDP port $port"
}
#endregion ========================================================================================

#region ====== Show current port proxy and firewall rules =========================================
Invoke-Expression "netsh interface portproxy show v4tov4"
Invoke-Expression "netsh advfirewall firewall show rule status=enabled name=all"
#endregion ========================================================================================