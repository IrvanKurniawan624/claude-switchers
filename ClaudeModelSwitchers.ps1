# ClaudeModelSwitchers.ps1
# Loaded by your PowerShell profile on startup.
# Dot-sources the core library, migrates legacy .env, and registers:
#   claude-switch  — pick or launch any provider
#   claude-config  — open the interactive config TUI
#   claude-<id>    — one function per enabled provider (auto-generated)

. (Join-Path $PSScriptRoot 'ClaudeSwitch.Core.ps1')
Initialize-SwitcherConfig

function claude-config {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'claude-config.ps1')
    # Reload dynamic provider functions after config may have changed
    . (Join-Path $PSScriptRoot 'ClaudeModelSwitchers.ps1')
}

function claude-switch {
    param(
        [Parameter(Position = 0)][string]$Id,
        [Parameter(Position = 1, ValueFromRemainingArguments)][string[]]$Rest
    )

    $config = Get-SwitcherConfig
    if (-not $config) { return }

    if (-not [string]::IsNullOrWhiteSpace($Id)) {
        Invoke-ClaudeProvider -Id $Id -Rest $Rest
        return
    }

    # Interactive picker when no ID supplied
    $enabled = @($config.providers | Where-Object { $_.enabled })
    if ($enabled.Count -eq 0) {
        Write-Host "No enabled providers. Run claude-config to enable one." -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Host '=== Select a provider ===' -ForegroundColor Cyan
    for ($i = 0; $i -lt $enabled.Count; $i++) {
        Write-Host ("  {0}  {1}" -f ($i + 1), $enabled[$i].name)
    }
    Write-Host ''
    $pick = Read-Host "Number"
    if ($pick -match '^\d+$') {
        $idx = [int]$pick - 1
        if ($idx -ge 0 -and $idx -lt $enabled.Count) {
            Invoke-ClaudeProvider -Id $enabled[$idx].id -Rest $Rest
        } else {
            Write-Host "Invalid selection." -ForegroundColor Yellow
        }
    }
}

# Dynamically create claude-<id> functions for every enabled provider
$__config = Get-SwitcherConfig
if ($__config) {
    foreach ($__p in $__config.providers) {
        if (-not $__p.enabled) { continue }
        $__id = $__p.id
        $__funcName = "claude-$__id"
        $__funcBody = [scriptblock]::Create("
            param([Parameter(ValueFromRemainingArguments)][string[]]`$Rest)
            Invoke-ClaudeProvider -Id '$__id' -Rest `$Rest
        ")
        Set-Item "function:global:$__funcName" -Value $__funcBody
    }
}
Remove-Variable __config, __p, __id, __funcName, __funcBody -ErrorAction SilentlyContinue
