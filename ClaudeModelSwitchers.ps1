# ClaudeModelSwitchers.ps1
# Loaded by your PowerShell profile on startup.
# Registers: claude-config, claude-switch, claude-status, claude-<id> per provider.

. (Join-Path $PSScriptRoot 'ClaudeSwitch.Core.ps1')
Initialize-SwitcherConfig

# Tracks which provider IDs have a registered claude-<id> function this session
# so deletions and disables can be cleaned up correctly on reload
$script:RegisteredProviderIds = @()

function claude-config {
    & (Join-Path $PSScriptRoot 'claude-config.ps1')
    # Re-sync provider functions: remove stale ones, register/update enabled ones
    $__rl = Get-SwitcherConfig
    # Remove every previously registered function first (handles deletions + disables)
    foreach ($__staleId in $script:RegisteredProviderIds) {
        Remove-Item "Function:\claude-$__staleId" -ErrorAction SilentlyContinue
    }
    $script:RegisteredProviderIds = @()
    if ($__rl) {
        foreach ($__rlp in $__rl.providers) {
            if ($__rlp.enabled) {
                $__rli = $__rlp.id
                Set-Item "function:global:claude-$__rli" -Value (
                    [scriptblock]::Create("param([Parameter(ValueFromRemainingArguments)][string[]]`$Rest); Invoke-ClaudeProvider -Id '$__rli' -Rest `$Rest")
                )
                $script:RegisteredProviderIds += $__rli
            }
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
    $config = Get-SwitcherConfig
    if (-not $config) { return }

    $enabled = @($config.providers | Where-Object { $_.enabled })
    if ($enabled.Count -eq 0) {
        Write-Host 'No enabled providers. Run claude-config to enable one.' -ForegroundColor Yellow
        return
    }

    Write-Host ''
    $sel = Invoke-Menu -Items ($enabled | ForEach-Object { $_.name }) -Title 'Select a provider'
    if ($sel -ge 0) {
        Invoke-ClaudeProvider -Id $enabled[$sel].id
    }
}

# Register claude-<id> for enabled providers; remove it for disabled ones
$__config = Get-SwitcherConfig
if ($__config) {
    foreach ($__p in $__config.providers) {
        $__id = $__p.id
        if ($__p.enabled) {
            Set-Item "function:global:claude-$__id" -Value (
                [scriptblock]::Create("
                    param([Parameter(ValueFromRemainingArguments)][string[]]`$Rest)
                    Invoke-ClaudeProvider -Id '$__id' -Rest `$Rest
                ")
            )
            $script:RegisteredProviderIds += $__id
        } else {
            Remove-Item "Function:\claude-$__id" -ErrorAction SilentlyContinue
        }
    }
}
Remove-Variable __config, __p, __id -ErrorAction SilentlyContinue
