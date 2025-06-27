# Modules/WSL2Module.psm1

#region ====== Resolve Paths ======================================================================
# Private initialization: resolve any external script paths at module import
function Initialize-WSL2Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable] $ScriptPaths
    )
    begin {
        # Create a module‐scoped hashtable to store resolved paths
        $script:ResolvedScripts = @{}
    }
    process {
        foreach ($key in $ScriptPaths.Keys) {
            $rel = $ScriptPaths[$key]
            try {
                $full = (Resolve-Path -Path (Join-Path $PSScriptRoot "..\$rel") -ErrorAction Stop).ProviderPath
                $script:ResolvedScripts[$key] = $full
                Write-Verbose "Resolved script '$key' → $full"
            }
            catch {
                Write-Error "Failed to resolve script for key '$key': $rel"
            }
        }
    }
}

# Run it once on module import
Initialize-WSL2Scripts -ScriptPaths $Global:WFMConfig.Scripts
#endregion

#region ====== Install Ubuntu 2204 ================================================================
<#
.SYNOPSIS
  Installs Ubuntu 22.04 under WSL2.

.DESCRIPTION
  Invokes the built-in WSL installer to add the Ubuntu-22.04 distribution.
  Supports WhatIf/Confirm so you can preview without actually installing.

.EXAMPLE
  Install-Ubuntu2204 -WhatIf

.NOTES
  Requires Windows 10 2004+ with the WSL optional feature enabled.
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
[OutputType()]
function Install-Ubuntu2204 {
    if ($PSCmdlet.ShouldProcess('WSL', 'Install Ubuntu-22.04')) {
        try {
            wsl --install -d 'Ubuntu-22.04'
            Write-Verbose 'Ubuntu-22.04 installation triggered.'
        }
        catch {
            Write-Error "Failed to launch installer: $($_.Exception.Message)"
        }
    }
}
#endregion

#region ====== Get WSL Distros ===================================================================
<#
.SYNOPSIS
  Lists all installed WSL distributions with their status.

.DESCRIPTION
  Runs `wsl --list --verbose`, parses its tabular output, and returns
  one object per distro with Name, State and Version properties.

.OUTPUTTYPE
  System.Management.Automation.PSCustomObject

.EXAMPLE
  Get-WSLDistro | Format-Table

.NOTES
  If parsing fails, raw text is returned in a single string.
#>
[CmdletBinding()]
[OutputType([PSCustomObject])]
function Get-WSLDistro {
    Write-Verbose 'Querying installed WSL distributions...'
    try {
        $raw = wsl --list --verbose 2>&1
    }
    catch {
        Write-Error "Failed to list WSL distros: $($_.Exception.Message)"
        return
    }

    # First line is header, skip it and any empty lines
    $lines = $raw -split "`r?`n" | Where-Object { $_.Trim() -and -not $_ -match '^NAME\s+' }

    $objects = foreach ($line in $lines) {
        # Expect: <Name> <State> <Version>
        $cols = $line -split '\s+', 3
        if ($cols.Count -eq 3) {
            [PSCustomObject]@{
                Name    = $cols[0]
                State   = $cols[1]
                Version = $cols[2]
            }
        }
    }

    if (-not $objects) {
        # fallback to raw output
        return [PSCustomObject]@{ RawOutput = $raw }
    }

    return $objects
}
#endregion

#region ====== Set Default WSL Distro =============================================================
<#
.SYNOPSIS
  Sets the default WSL distribution.

.DESCRIPTION
  Runs `wsl --set-default <Distro>` to configure which distro launches
  when you invoke `wsl` without a `-d` parameter.

.PARAMETER Distro
  The exact name of the WSL distro (e.g. 'Ubuntu-20.04').

.EXAMPLE
  Set-DefaultWSLDistro -Distro 'Ubuntu-20.04'

.NOTES
  Supports –WhatIf and –Confirm.
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
[OutputType()]
function Set-DefaultWSLDistro {
    param(
        [Parameter(Mandatory)][string]$Distro
    )

    if ($PSCmdlet.ShouldProcess("WSL Default Distro", "Set to '$Distro'")) {
        try {
            wsl --set-default $Distro
            Write-Verbose "Default WSL distro set to '$Distro'."
        }
        catch {
            Write-Error "Failed to set default distro: $($_.Exception.Message)"
        }
    }
}
#endregion

#region ====== Get Ports Used =====================================================================
<#
.SYNOPSIS
  Lists Docker containers running under WSL2 and their exposed host ports.

.DESCRIPTION
  Queries the specified WSL2 distro for active Docker container IDs,
  inspects each container’s port mappings, and returns a PSCustomObject
  with ContainerName and HostPort for each mapping.

.PARAMETER Distro
  The WSL2 distribution name to query (default: current).

.OUTPUTTYPE
  System.Management.Automation.PSCustomObject

.EXAMPLE
  Get-WSL2DockerUsedPorts -Distro 'Ubuntu-20.04' | Format-Table

.NOTES
  Docker must be installed and running inside the WSL2 distro.
#>
[CmdletBinding()]
[OutputType([PSCustomObject])]
function Get-WSL2DockerUsedPort {
    param(
        [string] $Distro = $env:WSL_DISTRO_NAME
    )

    Write-Verbose "Listing Docker containers in WSL2 distro '$Distro'..."
    try {
        $ids = wsl -d $Distro docker ps -q 2>&1
    }
    catch {
        Write-Error "Cannot list containers: $($_.Exception.Message)"
        return
    }

    if (-not $ids) {
        Write-Verbose 'No running containers found.'
        return
    }

    $ids | ForEach-Object {
        $id   = $_.Trim()
        $name = (wsl -d $Distro docker inspect --format '{{.Name}}' $id).Trim('/')
        $ports = wsl -d $Distro docker port $id 2>$null |
                 ForEach-Object { ($_ -split ':')[1].Trim() } |
                 Where-Object { $_ } | Sort-Object -Unique

        if ($ports) {
            foreach ($p in $ports) {
                [PSCustomObject]@{
                    ContainerName = $name
                    HostPort      = [int]$p
                }
            }
        }
        else {
            [PSCustomObject]@{
                ContainerName = $name
                HostPort      = $null
            }
        }
    }
}
#endregion

#region ====== Get Systemctl Status List ==========================================================
<#
.SYNOPSIS
  Retrieves running systemd services inside WSL2.

.DESCRIPTION
  Executes `systemctl list-units --type=service --state=running` in the
  default WSL2 distro, parses the output, and returns PSCustomObjects
  with ServiceName, Load, Active, SubState, and Description.

.PARAMETER Distro
  The WSL2 distribution to query (default: current).

.OUTPUTTYPE
  System.Management.Automation.PSCustomObject

.EXAMPLE
  Get-WSL2SystemctlStatusList | Where-Object Active -eq 'running'

.NOTES
  Requires WSL2 distro with systemd enabled.
#>
[CmdletBinding()]
[OutputType([PSCustomObject])]
function Get-WSL2SystemctlStatusList {
    param(
        [string] $Distro = $env:WSL_DISTRO_NAME
    )

    Write-Verbose "Querying systemd services in '$Distro'..."
    try {
        $raw = wsl -d $Distro -- bash -c "systemctl --no-pager --no-legend list-units --type=service --state=running" 2>&1
    }
    catch {
        Write-Error "systemctl invocation failed: $($_.Exception.Message)"
        return
    }

    if (-not $raw) {
        Write-Verbose 'No running services detected.'
        return
    }

    $raw -split "`r?`n" | ForEach-Object {
        $line = $_.Trim()
        if (-not $line) { return }

        $cols = $line -split '\s+', 5
        [PSCustomObject]@{
            ServiceName = $cols[0]
            Load        = $cols[1]
            Active      = $cols[2]
            SubState    = $cols[3]
            Description = if ($cols.Count -eq 5) { $cols[4] } else { '' }
        }
    }
}
#endregion

#region ====== Get WSL2 Hostnames =================================================================
#───────────────────────────────────────────────────────────────────────────────
<#
.SYNOPSIS
  Retrieves the list of hostnames from a WSL2 helper script.

.DESCRIPTION
  Looks up the configured script path for “WSL2_Hostnames” in the
  module‐scoped $script:ResolvedScripts hashtable, invokes it under
  PowerShell.exe, and returns each line of output as a string.

.PARAMETER Distro
  (Optional) The WSL2 distribution to use. Defaults to current ($env:WSL_DISTRO_NAME).

.OUTPUTTYPE
  System.String

.EXAMPLE
  Get-WSL2Hostnames -Verbose | Format-List

.NOTES
  • Requires Initialize-WSL2Scripts to have populated $script:ResolvedScripts.
  • Supports –Verbose for diagnostic tracing.
#>
[CmdletBinding()]
[OutputType([string])]
function Get-WSL2Hostname {
    param(
        [string] $Distro = $env:WSL_DISTRO_NAME
    )

    Write-Verbose "Retrieving WSL2 hostnames from distro '$Distro'..."

    $scriptKey = 'WSL2_Hostnames'
    if (-not $script:ResolvedScripts.ContainsKey($scriptKey)) {
        Throw "Hostname script path for key '$scriptKey' not found."
    }

    $scriptPath = $script:ResolvedScripts[$scriptKey]

    try {
        # Invoke external script and capture its output lines
        $lines = & pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Distro $Distro 2>&1
    }
    catch {
        Write-Error "Failed to run hostnames script: $($_.Exception.Message)"
        return
    }

    # Return non-empty trimmed lines
    return $lines |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}
#endregion

#region ====== Get WSL2 Hostinfo ==================================================================
<#
.SYNOPSIS
  Executes an external “hostinfo” script in WSL2 and returns its textual output.

.DESCRIPTION
  Looks up the configured script path for “WSL2_Hostinfo” in
  $script:ResolvedScripts, invokes it under PowerShell.exe, and returns
  each line of its output as a string.

.PARAMETER ScriptPath
  (Optional) Override path to the hostinfo PS1 script. Defaults to
  the resolved path in $script:ResolvedScripts['WSL2_Hostinfo'].

.OUTPUTTYPE
  System.String

.EXAMPLE
  Get-WSL2HostInfo | Out-File .\hostinfo.txt

.NOTES
  Supports –Verbose for tracing.
#>
[CmdletBinding()]
[OutputType([string])]
function Get-WSL2HostInfo {
    param(
        [string] $ScriptPath = $script:ResolvedScripts['WSL2_Hostinfo']
    )

    if (-not (Test-Path -Path $ScriptPath)) {
        Throw "Hostinfo script not found at: $ScriptPath"
    }

    Write-Verbose "Invoking hostinfo script: $ScriptPath"

    try {
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $ScriptPath 2>&1
    }
    catch {
        Write-Error "Failed to run hostinfo script: $($_.Exception.Message)"
        return
    }

    return $output
}
#endregion

#region ====== Get WSL2 Netstat ===================================================================
<#
.SYNOPSIS
  Parses WSL2’s netstat output into structured objects.

.DESCRIPTION
  Invokes netstat inside the specified WSL2 distro, parses TCP/UDP
  lines, and returns a PSCustomObject per connection with properties:
  Protocol, LocalAddress, LocalPort, RemoteAddress, RemotePort, State.

.PARAMETER Distro
  (Optional) The WSL2 distribution name. Defaults to current.

.OUTPUTTYPE
  System.Management.Automation.PSCustomObject

.EXAMPLE
  Get-WSL2Netstat | Where-Object { $_.State -eq 'LISTEN' }

.NOTES
  Requires net-tools (netstat) installed in the Linux distro.
#>
[CmdletBinding()]
[OutputType([PSCustomObject])]
function Get-WSL2Netstat {
    param(
        [string] $Distro = $env:WSL_DISTRO_NAME
    )

    Write-Verbose "Running netstat in distro '$Distro'..."

    try {
        $raw = wsl -d $Distro -- netstat -tuln 2>&1
    }
    catch {
        Write-Error "Failed to run netstat: $($_.Exception.Message)"
        return
    }

    $objects = foreach ($line in $raw -split "`r?`n") {
        $cols = $line.Trim() -split '\s+'
        # Expect: Proto, Recv-Q, Send-Q, Local, Remote, State
        if ($cols.Count -ge 6 -and $cols[0] -match '^(tcp|udp)') {
            $local  = $cols[3] -split ':'
            $remote = $cols[4] -split ':'
            [PSCustomObject]@{
                Protocol      = $cols[0]
                LocalAddress  = $local[0]
                LocalPort     = [int]$local[1]
                RemoteAddress = $remote[0]
                RemotePort    = [int]$remote[1]
                State         = $cols[5]
            }
        }
    }

    return $objects
}
#endregion

#region ====== Set WSL2 Swarm Ports Firewall ======================================================
<#
.SYNOPSIS
  Configures host firewall rules for WSL2 Docker Swarm ports.

.DESCRIPTION
  Invokes an external PowerShell script (NoProfile, Bypass) to create
  or update Windows firewall rules needed by Docker Swarm in WSL2.
  Supports –WhatIf/–Confirm.

.PARAMETER ScriptPath
  Path to the firewall‐ports script. Defaults to configured key 'WSL2_SwarmPortsFirewall'.

.EXAMPLE
  Set-WSL2SwarmPortsFirewall -WhatIf

.NOTES
  Relies on Initialize-WSL2Scripts having populated $script:ResolvedScripts.
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
[OutputType()]
function Set-WSL2SwarmPortsFirewall {
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath = $script:ResolvedScripts['WSL2_SwarmPortsFirewall']
    )

    if (-not (Test-Path $ScriptPath)) {
        Throw "Firewall script not found: $ScriptPath"
    }

    if ($PSCmdlet.ShouldProcess('WSL2 Swarm Firewall', "Invoke script $ScriptPath")) {
        try {
            Write-Verbose "Running firewall script: $ScriptPath"
            & pwsh -NoProfile -ExecutionPolicy Bypass -File $ScriptPath 2>&1 | ForEach-Object { Write-Verbose $_ }
        }
        catch {
            Throw "Swarm firewall script failed: $($_.Exception.Message)"
        }
    }
}
#endregion

#region ====== New WSL2 Docker Ports File =========================================================
<#
.SYNOPSIS
  Generates a Docker‐ports file via external WSL2 script.

.DESCRIPTION
  Executes a configured PowerShell script to enumerate TCP/UDP ports used
  by WSL2 containers and writes results to a host‐side text file.

.PARAMETER ScriptPath
  Path to the ports‐generation script. Defaults to key 'WSL2_DockerTCPUDPPorts'.

.EXAMPLE
  New-WSL2DockerPortsFile -Confirm

.NOTES
  Supports –WhatIf/–Confirm. No objects emitted.
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
[OutputType()]
function New-WSL2DockerPortsFile {
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath = $script:ResolvedScripts['WSL2_DockerTCPUDPPorts']
    )

    if (-not (Test-Path $ScriptPath)) {
        Throw "Ports script not found: $ScriptPath"
    }

    if ($PSCmdlet.ShouldProcess('WSL2 Docker Ports File', "Run script $ScriptPath")) {
        try {
            Write-Verbose "Running Docker ports script: $ScriptPath"
            & pwsh -NoProfile -ExecutionPolicy Bypass -File $ScriptPath 2>&1 | ForEach-Object { Write-Verbose $_ }
        }
        catch {
            Throw "Docker ports script failed: $($_.Exception.Message)"
        }
    }
}
#endregion

#region ====== Show WSL2 Docker Ports File ========================================================
<#
.SYNOPSIS
  Displays the WSL2 Docker ports output file.

.DESCRIPTION
  Reads a text file containing Docker‐ports output and writes each
  line to the console.

.PARAMETER FilePath
  Path to the ports‐output file. Defaults to key 'WSL2_DockerPortsOutput'.

.EXAMPLE
  Show-WSL2DockerPortsFile -FilePath 'C:\tmp\docker_ports.txt'

.OUTPUTTYPE
  System.String

.NOTES
  Suitable for piping or redirection.
#>
[CmdletBinding()]
[OutputType([string])]
function Show-WSL2DockerPortsFile {
    param(
        [Parameter(Mandatory)]
        [string] $FilePath = $script:ResolvedScripts['WSL2_DockerPortsOutput']
    )

    if (-not (Test-Path $FilePath)) {
        Write-Error "Ports file not found: $FilePath"
        return
    }

    Get-Content -Path $FilePath
}
#endregion

#region ====== Set Docker Set Rules ===============================================================
<#
.SYNOPSIS
  Applies Windows firewall rules for Docker in WSL2 via external script.

.DESCRIPTION
  Invokes the configured PowerShell script to set host firewall rules
  required by Docker Swarm inside WSL2. Exits with the child script’s code
  on failure.

.PARAMETER ScriptPath
  Path to the Docker‐rules script. Defaults to key 'WSL2_CreateDockerRules'.

.EXAMPLE
  Set-WSL2DockerRules -Confirm

.NOTES
  Supports –WhatIf/–Confirm.
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
[OutputType()]
function Set-WSL2DockerRule {
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath = $script:ResolvedScripts['WSL2_CreateDockerRules']
    )

    if (-not (Test-Path $ScriptPath)) {
        Throw "Docker rules script not found: $ScriptPath"
    }

    if ($PSCmdlet.ShouldProcess('WSL2 Docker Rules', "Invoke script $ScriptPath")) {
        try {
            Write-Verbose "Running Docker rules script: $ScriptPath"
            & pwsh -NoProfile -ExecutionPolicy Bypass -File $ScriptPath 2>&1 | ForEach-Object { Write-Verbose $_ }
        }
        catch {
            Throw "Docker rules script failed: $($_.Exception.Message)"
        }
    }
}
#endregion

#region ====== Show Port Mappings =================================================================
<#
.SYNOPSIS
  Retrieves WSL2 portproxy mappings as objects.

.DESCRIPTION
  Parses the output of `netsh interface portproxy show v4tov4` into
  PSCustomObjects with properties LocalIP, LocalPort, RemoteIP, RemotePort,
  Protocol, AppName, and optionally checks for matching firewall rules.

.PARAMETER CheckFirewall
  Switch. When specified, tests if an inbound firewall rule exists for each LocalPort.

.PARAMETER SortBy
  Property name to sort by: LocalPort, LocalIP, RemotePort, RemoteIP.

.PARAMETER Descending
  Switch. When specified, sorts in descending order.

.OUTPUTTYPE
  System.Management.Automation.PSCustomObject

.EXAMPLE
  # Get mappings, check firewall rules, sort by RemotePort descending
  Get-WSL2PortMappings -CheckFirewall -SortBy RemotePort -Descending

.NOTES
  • Requires elevated privileges for firewall checks.
  • This cmdlet does not interactively prompt.
#>
function Get-WSL2PortMapping {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [switch] $CheckFirewall,
        [ValidateSet('LocalPort','LocalIP','RemotePort','RemoteIP')]
        [string] $SortBy = 'LocalPort',
        [switch] $Descending
    )

    # Run netsh and skip header/footer lines
    $raw = netsh interface portproxy show v4tov4 2>&1
    if (-not $raw) {
        Write-Verbose 'No portproxy entries found.'
        return
    }
    $lines = $raw -split "`r?`n" |
             Where-Object { $_.Trim() } |
             Select-Object -Skip 4  # skip title + headers

    $results = foreach ($line in $lines) {
        # Columns: ListenOnAddr ListenOnPort ConnectToAddr ConnectToPort Protocol [AppName]
        $cols = $line -split '\s+', 6
        if ($cols.Count -lt 5) { continue }

        $obj = [PSCustomObject]@{
            LocalIP        = $cols[0]
            LocalPort      = [int]$cols[1]
            RemoteIP       = $cols[2]
            RemotePort     = [int]$cols[3]
            Protocol       = $cols[4]
            AppName        = if ($cols.Count -ge 6) { $cols[5] } else { '' }
            HasFirewallRule= $false
        }

        if ($CheckFirewall) {
            try {
                $exists = Get-NetFirewallRule -Direction Inbound -Enabled True |
                          Get-NetFirewallPortFilter |
                          Where-Object LocalPort -eq $obj.LocalPort
                $obj.HasFirewallRule = [bool]$exists
            }
            catch {
                Write-Warning "Firewall query failed for port $($obj.LocalPort): $_"
            }
        }

        $obj
    }

    # Sort
    if ($SortBy) {
        $order = if ($Descending) { 'Descending' } else { 'Ascending' }
        $results = $results | Sort-Object -Property $SortBy -Descending:$Descending
    }

    return $results
}
#endregion

#region ====== Show Port Mappings Table ===========================================================
<#
.SYNOPSIS
  Formats and displays WSL2 portproxy mappings in a table.

.DESCRIPTION
  Accepts PSCustomObjects (from Get-WSL2PortMappings) via pipeline or parameter,
  then writes a formatted table to the host.

.PARAMETER InputObject
  One or more portmapping objects (ValueFromPipeline).

.PARAMETER AutoSize
  Switch. When set, passes –AutoSize to Format-Table.

.EXAMPLE
  Get-WSL2PortMappings -CheckFirewall | Show-WSL2PortMappingsTable

.NOTES
  This cmdlet writes directly to the host; it emits no objects.
#>
function Show-WSL2PortMappingsTable {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [PSCustomObject[]] $InputObject,
        [switch] $AutoSize
    )
    begin {
        $buffer = @()
    }
    process {
        if ($null -ne $InputObject) {
            $buffer += $InputObject
        }
    }
    end {
        if (-not $buffer) {
            Write-Host 'No portproxy mappings to display.' -ForegroundColor Yellow
            return
        }
        $formatParams = @{
            Property = @(
                @{Label='App';        Expression={$_.AppName}}
                @{Label='Proto';      Expression={$_.Protocol}}
                @{Label='Local IP';   Expression={$_.LocalIP}}
                @{Label='Local Port'; Expression={$_.LocalPort}}
                @{Label='Remote IP';  Expression={$_.RemoteIP}}
                @{Label='Remote Port';Expression={$_.RemotePort}}
                @{Label='Has FW Rule';Expression={$_.HasFirewallRule}}
            )
        }
        if ($AutoSize) {
            $formatParams.AutoSize = $true
        }
        $buffer | Format-Table @formatParams
    }
}
#endregion

#region ====== Export Module Member ===============================================================
# Public API for WSL2 helper module
$PublicFunctions = @(
    'Install-Ubuntu2204'
    'Get-WSLDistro'
    'Set-DefaultWSLDistro'
    'Get-WSL2DockerUsedPorts'
    'Get-WSL2SystemctlStatusList'
    'Get-WSL2Hostnames'
    'Get-WSL2HostInfo'
    'Get-WSL2Netstat'
    'Set-WSL2SwarmPortsFirewall'
    'New-WSL2DockerPortsFile'
    'Show-WSL2DockerPortsFile'
    'Set-WSL2DockerRules'
    'Get-WSL2PortMappings'
    'Show-WSL2PortMappingsTable'
)

Export-ModuleMember -Function $PublicFunctions
#endregion