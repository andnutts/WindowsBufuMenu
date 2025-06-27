function Send-Telemetry {
    param($EventName, $Properties)
    if (-not $Global:Config.Telemetry.Enabled) { return }
    $payload = @{
        event   = $EventName
        time    = (Get-Date).ToString('o')
        props   = $Properties
    } | ConvertTo-Json
    # fire-and-forget
    try {
        Invoke-RestMethod -Uri $Global:Config.Telemetry.Endpoint `
                          -Method Post -Body $payload -ContentType 'application/json'
    } catch { }
}

Export-ModuleMember -Function Send-Telemetry
