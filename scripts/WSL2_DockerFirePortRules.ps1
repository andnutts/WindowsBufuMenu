# scripts/WSL2_DockerFirePortRules.ps1

$wsl2Hostname = wsl hostname
$dispGroup = "WSL2"
$pcName = $env:COMPUTERNAME
$scriptDir = "$env:USERPROFILE\scripts"

#region ====== File path to read the container details ============================================
$inputFile = "$scriptDir\configs\output\docker_${wsl2Hostname}_containers_info.txt"
#endregion ========================================================================================

#region ====== File path to save the log details ==================================================
$logFile = "$scriptDir\logs\${pcName}_WSL2_${wsl2Hostname}_rules.log"
#endregion ========================================================================================

#region ====== Get the Wsl2 IP address ============================================================
$remoteport = ((wsl hostname -I) -split " ")[0]
$found = $remoteport -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';
#endregion ========================================================================================

#region ====== Read container details from file ===================================================
$containerDetails = Get-Content -Path $inputFile | Select-Object -Skip 1
#endregion ========================================================================================

#region ====== Clear previous log file ============================================================
if (Test-Path $logFile) {
    Remove-Item $logFile
}
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Write header to log file
"$Timestamp : Action : Details" | Out-File -FilePath $logFile -Encoding UTF8 -Append
#endregion ========================================================================================

#region ====== Create firewall and port proxy rules ===============================================
foreach ($detail in $containerDetails) {
    $name, $hostPort, $containerPort, $protocol = $detail -split ' : '

    #region ---- Skip port 2375 -------------------------------------------------------------------
    if ($hostPort -eq '2375') {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp : Skipping port 2375 for container $name" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        Write-Output "Skipping port 2375 for container ${name}"
        continue
    }
    #endregion ------------------------------------------------------------------------------------    
    #region ---- Validate the protocol ------------------------------------------------------------
    if ($protocol -eq 'tcp' -or $protocol -eq 'udp') {
        $protocol = $protocol.ToUpper()
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        #region ---- Remove old firewall rules if they exist --------------------------------------
        $firewallRuleNameInbound = "Inbound_DockerContainer_$name"
        $firewallRuleNameOutbound = "Outbound_DockerContainer_$name"
        # $firewallRuleNameInbound = "Docker_$name on $hostPort(Inbound)"
        # $firewallRuleNameOutbound = "Docker_$name on $hostPort(Outbound)"
        if (Get-NetFirewallRule -DisplayName $firewallRuleNameInbound -ErrorAction SilentlyContinue) {
            Remove-NetFirewallRule -DisplayName $firewallRuleNameInbound
            "$timestamp : Removed old inbound firewall rule : $firewallRuleNameInbound" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        }
        if (Get-NetFirewallRule -DisplayName $firewallRuleNameOutbound -ErrorAction SilentlyContinue) {
            Remove-NetFirewallRule -DisplayName $firewallRuleNameOutbound
            "$timestamp : Removed old outbound firewall rule : $firewallRuleNameOutbound" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        }
        #endregion --------------------------------------------------------------------------------
        #region ---- Add inbound firewall rule ----------------------------------------------------
        $firewallRuleNameInbound = "Docker_$name on $hostPort(Inbound)"
        New-NetFirewallRule -DisplayName $firewallRuleNameInbound -Group $dispGroup -Direction Inbound -Action Allow -Protocol $protocol -LocalPort $hostPort -Profile Any
        "$timestamp : Created inbound firewall rule : $firewallRuleNameInbound" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        Write-Output "Inbound Firewall rule created for ${name}"
        #endregion --------------------------------------------------------------------------------
        #region ---- Add outbound firewall rule ---------------------------------------------------
        $firewallRuleNameOutbound = "Docker_$name on $hostPort(Outbound)"
        New-NetFirewallRule -DisplayName $firewallRuleNameOutbound -Group $dispGroup -Direction Outbound -Action Allow -Protocol $protocol -LocalPort $hostPort -Profile Any
        "$timestamp : Created outbound firewall rule : $firewallRuleNameOutbound" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        Write-Output "Outbound Firewall rule created for ${name}"
        #endregion --------------------------------------------------------------------------------
        #region ---- Remove old port proxy rule if it exists --------------------------------------
        netsh interface portproxy delete v4tov4 listenport=$hostPort listenaddress=0.0.0.0
        "$timestamp : Removed old port proxy rule on port ${hostPort}" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        #endregion --------------------------------------------------------------------------------
        #region ---- Add port proxy rule ----------------------------------------------------------
        $portProxyName = "Docker_$name"
        netsh interface portproxy delete v4tov4 listenport=$hostPort listenaddress=0.0.0.0
        netsh interface portproxy add v4tov4 listenport=$hostPort listenaddress=0.0.0.0 connectaddress=$remoteport connectport=$hostPort
        "$timestamp : Created port proxy rule : $portProxyName (HostPort: $hostPort, ContainerPort: $containerPort, Protocol: $protocol)" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        Write-Output "Port proxy rule created for ${name} on port ${hostPort}"
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp : Skipping invalid protocol for container $name : $protocol" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        Write-Output "Skipping Invalid protocol for container ${name}: ${protocol}"
        #endregion -----------------------------------------------------------------------------------
    }
    #endregion ------------------------------------------------------------------------------------
}
#endregion ========================================================================================

#region ====== Show Firewall Rules ================================================================
netsh advfirewall firewall show rule status=enabled name=all | find "Rule Name:" | select-string "Allow"
Write-Output "Old rules removed and new firewall and port proxy rules created based on $inputFile. Log saved to $logFile."
#endregion ========================================================================================