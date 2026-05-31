# claude-switch.ps1
# Interactive provider picker (or direct launch if ID is given).
# Used by claude-switch.cmd for CMD support.
param(
    [Parameter(Position = 0)][string]$Id,
    [Parameter(Position = 1, ValueFromRemainingArguments)][string[]]$Rest
)

. (Join-Path $PSScriptRoot 'ClaudeSwitch.Core.ps1')
Initialize-SwitcherConfig

if (-not [string]::IsNullOrWhiteSpace($Id)) {
    Invoke-ClaudeProvider -Id $Id -Rest $Rest
    exit
}

$config  = Get-SwitcherConfig
$enabled = @($config.providers | Where-Object { $_.enabled })

if ($enabled.Count -eq 0) {
    Write-Host 'No enabled providers. Run claude-config to enable one.' -ForegroundColor Yellow
    exit 1
}

Write-Host ''
$sel = Invoke-Menu -Items ($enabled | ForEach-Object { $_.name }) -Title 'Select a provider'
if ($sel -ge 0) {
    Invoke-ClaudeProvider -Id $enabled[$sel].id -Rest $Rest
}
