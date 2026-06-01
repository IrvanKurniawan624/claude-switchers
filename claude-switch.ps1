# claude-switch.ps1
# Interactive provider picker. Used by claude-switch.cmd for CMD support.

. (Join-Path $PSScriptRoot 'ClaudeSwitch.Core.ps1')
Initialize-SwitcherConfig

$config = Get-SwitcherConfig
if (-not $config) { Write-Error 'Cannot load config.'; exit 1 }
$enabled = @($config.providers | Where-Object { $_.enabled })

if ($enabled.Count -eq 0) {
    Write-Host 'No enabled providers. Run claude-config to enable one.' -ForegroundColor Yellow
    exit 1
}

Write-Host ''
$sel = Invoke-Menu -Items ($enabled | ForEach-Object { $_.name }) -Title 'Select a provider'
if ($sel -ge 0) {
    Invoke-ClaudeProvider -Id $enabled[$sel].id
}
