# scripts/WSL2_DockerTcpUdpPorts.ps1

#region ====== WSL2 Variables =====================================================================
$wsl2Hostname = wsl hostname
$scriptDir = "$env:USERPROFILE\scripts"
# File path to save the container details
$outputFile = "$scriptDir\configs\output\docker_${wsl2Hostname}_containers_info.txt"
#endregion ========================================================================================

#region ====== Ensure the output directory exists =================================================
$outputDir = [System.IO.Path]::GetDirectoryName($outputFile)
if (-Not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir
}
#endregion ========================================================================================

#region ====== Clear the file before writing to it ================================================
"" | Out-File -FilePath $outputFile -Encoding UTF8 -Force
#endregion ========================================================================================

#region ====== Initialize a set to track unique host ports ========================================
$uniqueHostPorts = [System.Collections.Generic.HashSet[int]]::new()
$containerDetails = @()
#endregion ========================================================================================

#region ====== Get Docker container details =======================================================
$dockerContainers = wsl docker ps --format '{{.Names}}:{{.Ports}}'
#endregion ========================================================================================

#region ====== Write header to file ===============================================================
"Container Name : Host Ports : Container Port : Protocol" | Out-File -FilePath $outputFile -Encoding UTF8 -Append
foreach ($container in $dockerContainers) { 
     $name, $ports = $container -split ':'
     if ($name -match '\.') {
        $name = $name -split '\.' | Select-Object -First 1
    }
     $portDetails = $ports -split ',' 
     foreach ($portDetail in $portDetails) {
         if ($portDetail -match '->') { 
             $hostPort, $containerPortWithProtocol = $portDetail -split '->'
             $containerPort, $protocol = $containerPortWithProtocol -split '/'
        } else {
            $containerPort, $protocol = $portDetail -split '/'
            $hostPort = $containerPort
        }
        if ($hostPort -match '^[0-9]+$' -and [int]$hostPort -ge 0 -and [int]$hostPort -le 65535) {
            if ($uniqueHostPorts.Add([int]$hostPort)) {
                Write-Output "Container: $($name) : Host Port: $($hostPort) : Container Port: $($containerPort) : Protocol: $($protocol)"
                "$name : $hostPort : $containerPort : $protocol" | Out-File -FilePath $outputFile -Encoding UTF8 -Append
	        }
        }
    } 
}
#endregion ========================================================================================

#region ====== Sort the container details by HostPort in ascending order ==========================
$sortedContainerDetails = $containerDetails | Sort-Object -Property HostPort
#endregion ========================================================================================

#region ====== Write sorted container details to the output file ==================================
foreach ($detail in $sortedContainerDetails) {
    Write-Output "Container: $($detail.Name) : Host Port: $($detail.HostPort) : Container Port: $($detail.ContainerPort) : Protocol: $($detail.Protocol)"
    "$($detail.Name) : $($detail.HostPort) : $($detail.ContainerPort) : $($detail.Protocol)" | Out-File -FilePath $outputFile -Encoding UTF8 -Append
}
#endregion ========================================================================================

Write-Output "Docker container information saved to $outputFile"