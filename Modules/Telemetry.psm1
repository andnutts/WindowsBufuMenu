<#
.SYNOPSIS
  Sends a custom telemetry event to a configured REST endpoint.

.DESCRIPTION
  Constructs a JSON payload containing the event name, timestamp, and
  optional properties, then POSTs it asynchronously to your telemetry
  service. Silently skips sending if telemetry is disabled.

.PARAMETER EventName
  A string identifier for the event (e.g. “AppStart”, “UserAction”).

.PARAMETER Properties
  A hashtable of additional event metadata to include in the payload.

.OUTPUTTYPE
  None

.EXAMPLE
  Send-Telemetry -EventName 'AppStart' -Properties @{ Version = '1.2.3'; User = $env:USERNAME }

.NOTES
  • Reads configuration from $script:Config.Telemetry (Enabled, Endpoint).  
  • Failures in HTTP calls are caught and only emit a warning.  
  • Requires Internet connectivity and valid endpoint URI.
#>
[CmdletBinding()]
[OutputType([void])]
function Send-Telemetry {
    param(
        [Parameter(Mandatory)][string]    $EventName,
        [Parameter()]       [hashtable]   $Properties = @{}
    )

    # Script‐scoped config object (set earlier in your module)
    if (-not $script:Config.Telemetry.Enabled) {
        Write-Verbose "Telemetry disabled; skipping event '$EventName'."
        return
    }

    $endpoint = $script:Config.Telemetry.Endpoint
    if (-not $endpoint) {
        Write-Warning "Telemetry endpoint not configured; cannot send event."
        return
    }

    $payload = @{
        event      = $EventName
        timestamp  = (Get-Date).ToString('o')
        properties = $Properties
    } | ConvertTo-Json -Depth 5

    try {
        # fire-and-forget HTTP POST
        Invoke-RestMethod `
          -Uri         $endpoint `
          -Method      Post `
          -Body        $payload `
          -ContentType 'application/json' `
          -TimeoutSec  5 `
          -ErrorAction Stop
        Write-Verbose "Telemetry event '$EventName' sent successfully."
    }
    catch {
        Write-Warning "Failed to send telemetry '$EventName': $($_.Exception.Message)"
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Export public function(s)
Export-ModuleMember -Function Send-Telemetry
```