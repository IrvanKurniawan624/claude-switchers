# ClaudeModelSwitchers.ps1
# Loaded by your PowerShell profile on startup.
# Registers: claude-config, claude-switch, claude-status, claude-<id> per provider.

. (Join-Path $PSScriptRoot 'ClaudeSwitch.Core.ps1')
Initialize-SwitcherConfig

function claude-config {
    # Run inline (same process/terminal — no subprocess window)
    & (Join-Path $PSScriptRoot 'claude-config.ps1')
    # Re-register only provider functions for newly enabled providers.
    # Do NOT dot-source the whole file — that would re-run Initialize-SwitcherConfig
    # and the .env migration on every config exit.
    $__rl = Get-SwitcherConfig
    if ($__rl) {
        foreach ($__rlp in $__rl.providers) {
            if (-not $__rlp.enabled) { continue }
            $__rli = $__rlp.id
            Set-Item "function:global:claude-$__rli" -Value (
                [scriptblock]::Create("param([Parameter(ValueFromRemainingArguments)][string[]]`$Rest); Invoke-ClaudeProvider -Id '$__rli' -Rest `$Rest")
            )
        }
    }
    Remove-Variable __rl, __rlp, __rli -ErrorAction SilentlyContinue
}

function claude-status {
    $active = $env:CLAUDE_ACTIVE_PROVIDER
    if ([string]::IsNullOrWhiteSpace($active)) {
        Write-Host ''
        Write-Host '  No provider active in this session.' -ForegroundColor DarkGray
        Write-Host '  Run claude-pro, claude-deepseek, etc. to set one.' -ForegroundColor DarkGray
        Write-Host ''
        return
    }
    $config = Get-SwitcherConfig
    $p      = if ($config) { $config.providers | Where-Object { $_.id -eq $active } } else { $null }
    $name   = if ($p) { $p.name } else { $active }
    Write-Host ''
    Write-Host "  Active : $name" -ForegroundColor Cyan
    if ($env:ANTHROPIC_BASE_URL) {
        Write-Host "  URL    : $env:ANTHROPIC_BASE_URL" -ForegroundColor DarkGray
    } else {
        Write-Host "  URL    : (Anthropic default)" -ForegroundColor DarkGray
    }
    if ($env:ANTHROPIC_MODEL) {
        Write-Host "  Model  : $env:ANTHROPIC_MODEL" -ForegroundColor DarkGray
    }
    Write-Host ''
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

    $enabled = @($config.providers | Where-Object { $_.enabled })
    if ($enabled.Count -eq 0) {
        Write-Host 'No enabled providers. Run claude-config to enable one.' -ForegroundColor Yellow
        return
    }

    Write-Host ''
    $sel = Invoke-Menu -Items ($enabled | ForEach-Object { $_.name }) -Title 'Select a provider'
    if ($sel -ge 0) {
        Invoke-ClaudeProvider -Id $enabled[$sel].id -Rest $Rest
    }
}

# Dynamically register claude-<id> for every enabled provider
$__config = Get-SwitcherConfig
if ($__config) {
    foreach ($__p in $__config.providers) {
        if (-not $__p.enabled) { continue }
        $__id = $__p.id
        Set-Item "function:global:claude-$__id" -Value (
            [scriptblock]::Create("
                param([Parameter(ValueFromRemainingArguments)][string[]]`$Rest)
                Invoke-ClaudeProvider -Id '$__id' -Rest `$Rest
            ")
        )
    }
}
Remove-Variable __config, __p, __id -ErrorAction SilentlyContinue
