# Replace-WriteHost.ps1

param (
    [Parameter(Mandatory = $true)]
    [string]$InputFilePath,

    [Parameter(Mandatory = $true)]
    [string]$OutputFilePath,

    [ValidateSet("Output", "Verbose", "Information")]
    [string]$ReplacementType = "Verbose"
)

# Read the original script
$content = Get-Content -Path $InputFilePath

# Define the replacement command
switch ($ReplacementType) {
    "Output"      { $replacementCmd = "Write-Output" }
    "Verbose"     { $replacementCmd = "Write-Verbose" }
    "Information" { $replacementCmd = "Write-Information" }
}

# Replace Write-Host with the selected command
$modifiedContent = $content -replace 'Write-Host', $replacementCmd

# Save the modified script
$modifiedContent | Set-Content -Path $OutputFilePath

Write-Host "Replaced Write-Host with $replacementCmd and saved to $OutputFilePath"
