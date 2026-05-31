# ClaudeSwitch.Core.ps1
# Shared config/launch functions for claude-switchers.
# Dot-source this file; do not execute directly.

$script:SwitcherDir = $PSScriptRoot

# All ANTHROPIC_* and related env vars that can be overridden by a provider.
# These are cleared first on every launch so stale values from a previous
# provider cannot bleed through.
$script:ManagedEnvVars = @(
    'ANTHROPIC_BASE_URL',
    'ANTHROPIC_AUTH_TOKEN',
    'ANTHROPIC_API_KEY',
    'ANTHROPIC_MODEL',
    'ANTHROPIC_DEFAULT_OPUS_MODEL',
    'ANTHROPIC_DEFAULT_SONNET_MODEL',
    'ANTHROPIC_DEFAULT_HAIKU_MODEL',
    'CLAUDE_CODE_SUBAGENT_MODEL',
    'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
    'CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK',
    'CLAUDE_CODE_EFFORT_LEVEL',
    'API_TIMEOUT_MS'
)

# ---------------------------------------------------------------------------
# Arrow-key menu engine (shared by claude-config and claude-switch)
# Returns selected index, or -1 on Escape. Pass '--' for visual separators.
# ---------------------------------------------------------------------------
function Invoke-Menu {
    param(
        [string[]]$Items,
        [string]$Title = '',
        [int]$Default = 0
    )
    $count = $Items.Count
    $idx   = $Default
    while ($idx -lt $count -and $Items[$idx] -eq '--') { $idx++ }

    $W          = [Math]::Max(60, [Console]::WindowWidth - 4)
    $totalLines = $count + 5  # title + blank + items + blank + footer

    # Print blank lines to guarantee the menu fits without scrolling mid-draw.
    # This scrolls the buffer upfront so $startTop stays valid on every redraw.
    Write-Host ("`n" * $totalLines) -NoNewline
    $startTop = [Console]::CursorTop - $totalLines
    if ($startTop -lt 0) { $startTop = 0 }
    [Console]::SetCursorPosition(0, $startTop)

    $firstDraw = $true

    while ($true) {
        if (-not $firstDraw) { [Console]::SetCursorPosition(0, $startTop) }
        $firstDraw = $false

        if ($Title) { Write-Host ("  $Title").PadRight($W) -ForegroundColor Cyan }
        Write-Host (''.PadRight($W))

        for ($i = 0; $i -lt $count; $i++) {
            if ($Items[$i] -eq '--') {
                Write-Host ("  " + ('-' * ($W - 4))).PadRight($W) -ForegroundColor DarkGray
            } elseif ($i -eq $idx) {
                Write-Host ("  > " + $Items[$i]).PadRight($W) -ForegroundColor White
            } else {
                Write-Host ("    " + $Items[$i]).PadRight($W) -ForegroundColor DarkGray
            }
        }
        Write-Host (''.PadRight($W))
        Write-Host ("  [up/down] move   [enter] select   [esc] back").PadRight($W) -ForegroundColor DarkGray

        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        switch ($key.VirtualKeyCode) {
            38 { $n = $idx - 1; while ($n -ge 0 -and $Items[$n] -eq '--') { $n-- }; if ($n -ge 0) { $idx = $n } }
            40 { $n = $idx + 1; while ($n -lt $count -and $Items[$n] -eq '--') { $n++ }; if ($n -lt $count) { $idx = $n } }
            13 { Write-Host ''; return $idx }
            27 { Write-Host ''; return -1 }
        }
    }
}

# ---------------------------------------------------------------------------
# API key validation
# ---------------------------------------------------------------------------
function Test-ProviderKey {
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][string]$ApiKey
    )
    Write-Host '  Testing connection...' -ForegroundColor DarkGray -NoNewline
    try {
        $headers = @{
            'Authorization'     = "Bearer $ApiKey"
            'x-api-key'         = $ApiKey
            'anthropic-version' = '2023-06-01'
        }
        # Avoid double /v1 for providers whose baseUrl already ends with /v1
        $testBase = $BaseUrl.TrimEnd('/')
        $testUrl  = if ($testBase -match '/v1$') { "$testBase/models" } else { "$testBase/v1/models" }
        $resp = Invoke-WebRequest -Uri $testUrl -Headers $headers `
            -Method GET -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
        Write-Host " OK ($($resp.StatusCode))" -ForegroundColor Green
        return $true
    } catch {
        $code = $null
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        if ($code -eq 401 -or $code -eq 403) {
            Write-Host " invalid key (HTTP $code)" -ForegroundColor Red
            return $false
        } elseif ($code) {
            # Server responded but endpoint may not support /models — key likely fine
            Write-Host " reachable, key untested (HTTP $code)" -ForegroundColor Yellow
            return $true
        } else {
            Write-Host " could not connect: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
}

# ---------------------------------------------------------------------------
# Config read / write
# ---------------------------------------------------------------------------

function Get-SwitcherConfig {
    $configPath = Join-Path $script:SwitcherDir 'config.json'
    $examplePath = Join-Path $script:SwitcherDir 'config.example.json'

    if (-not (Test-Path $configPath)) {
        if (Test-Path $examplePath) {
            Copy-Item $examplePath $configPath
        } else {
            Write-Warning "config.example.json not found in $script:SwitcherDir"
            return $null
        }
    }

    try {
        $raw = Get-Content $configPath -Raw -Encoding UTF8
        return $raw | ConvertFrom-Json
    } catch {
        Write-Error "Failed to parse config.json: $_"
        return $null
    }
}

function Save-SwitcherConfig {
    param([Parameter(Mandatory)][object]$Config)
    $configPath = Join-Path $script:SwitcherDir 'config.json'
    $Config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Migration from legacy .env
# ---------------------------------------------------------------------------

function Initialize-SwitcherConfig {
    $config = Get-SwitcherConfig
    if (-not $config) { return }

    # Load .env into current process (same as legacy ClaudeModelSwitchers.ps1)
    $envFile = Join-Path $script:SwitcherDir '.env'
    if (Test-Path $envFile) {
        Get-Content $envFile | Where-Object { $_ -match '^\s*[^#=\s]' } | ForEach-Object {
            $parts = $_ -split '=', 2
            if ($parts.Count -eq 2) {
                $k = $parts[0].Trim(); $v = $parts[1].Trim()
                if (-not [System.Environment]::GetEnvironmentVariable($k)) {
                    [System.Environment]::SetEnvironmentVariable($k, $v, 'Process')
                }
            }
        }
    }

    # Migrate DEEPSEEK_API_KEY from .env into deepseek provider entry
    $legacyKey = $env:DEEPSEEK_API_KEY
    if ($legacyKey) {
        $deepseek = $config.providers | Where-Object { $_.id -eq 'deepseek' }
        if ($deepseek -and [string]::IsNullOrWhiteSpace($deepseek.apiKey)) {
            $deepseek.apiKey = $legacyKey
            Save-SwitcherConfig $config
        }
    }
}

# ---------------------------------------------------------------------------
# Launch a provider
# ---------------------------------------------------------------------------

function Invoke-ClaudeProvider {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(ValueFromRemainingArguments)][string[]]$Rest
    )

    $config = Get-SwitcherConfig
    if (-not $config) { Write-Error 'Cannot load config.'; return }

    $provider = $config.providers | Where-Object { $_.id -eq $Id }
    if (-not $provider) {
        Write-Error "Unknown provider '$Id'. Run claude-config to see available providers."
        return
    }

    # Clear fixed managed vars AND any extra vars set by the previous provider launch
    $prevKeys = $env:CLAUDE_ACTIVE_ENV_KEYS
    if (-not [string]::IsNullOrWhiteSpace($prevKeys)) {
        $prevKeys -split ',' | ForEach-Object {
            $k = $_.Trim()
            if ($k) { [System.Environment]::SetEnvironmentVariable($k, $null, 'Process') }
        }
    }
    foreach ($v in $script:ManagedEnvVars) {
        [System.Environment]::SetEnvironmentVariable($v, $null, 'Process')
    }

    $env:CLAUDE_ACTIVE_PROVIDER = $provider.id

    if ($provider.type -eq 'subscription') {
        # Record managed vars so the next provider launch clears them correctly
        $env:CLAUDE_ACTIVE_ENV_KEYS = ($script:ManagedEnvVars -join ',')
        Write-Host "Claude Code session set to Claude Pro (subscription defaults)." -ForegroundColor Cyan
    } else {
        # Resolve API key: config.json → ${ID}_API_KEY env var → legacy DEEPSEEK_API_KEY (deepseek only)
        $apiKey = $provider.apiKey
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            $envVarName = ($provider.id.ToUpper() -replace '[^A-Z0-9]', '_') + '_API_KEY'
            $apiKey = [System.Environment]::GetEnvironmentVariable($envVarName)
        }
        if ([string]::IsNullOrWhiteSpace($apiKey) -and $provider.id -eq 'deepseek') {
            $apiKey = $env:DEEPSEEK_API_KEY
        }

        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            Write-Host "No API key set for '$($provider.name)'." -ForegroundColor Yellow
            Write-Host "Run claude-config to set your key, or set `$env:$($provider.id.ToUpper())_API_KEY for this session." -ForegroundColor Yellow
            return
        }

        $env:ANTHROPIC_BASE_URL = $provider.baseUrl
        $env:ANTHROPIC_AUTH_TOKEN = $apiKey

        # Apply extra env vars from provider config
        $extraKeys = @()
        if ($provider.env) {
            $provider.env.PSObject.Properties | ForEach-Object {
                [System.Environment]::SetEnvironmentVariable($_.Name, $_.Value, 'Process')
                $extraKeys += $_.Name
            }
        }

        # Record all keys set this launch so next switch can clean them up
        $allKeys = ($script:ManagedEnvVars + $extraKeys) | Sort-Object -Unique
        $env:CLAUDE_ACTIVE_ENV_KEYS = $allKeys -join ','

        $modelDisplay = if ($provider.env -and $provider.env.ANTHROPIC_MODEL) { $provider.env.ANTHROPIC_MODEL } else { '(default)' }
        Write-Host "Claude Code session set to $($provider.name): $modelDisplay" -ForegroundColor Cyan
    }

    if ($Rest.Count -gt 0) {
        & claude @Rest
    } else {
        & claude
    }
}

# ---------------------------------------------------------------------------
# Regenerate CMD shims in launchers\
# ---------------------------------------------------------------------------

function Update-ClaudeLaunchers {
    $launchersDir = Join-Path $script:SwitcherDir 'launchers'
    if (-not (Test-Path $launchersDir)) {
        New-Item -ItemType Directory -Path $launchersDir | Out-Null
    }

    $config = Get-SwitcherConfig
    if (-not $config) { return }

    # Remove stale shims
    Get-ChildItem $launchersDir -Filter 'claude-*.cmd' | Remove-Item -Force

    $launchScript = Join-Path $script:SwitcherDir 'claude-launch.ps1'

    foreach ($provider in $config.providers) {
        if (-not $provider.enabled) { continue }
        $shimPath = Join-Path $launchersDir "claude-$($provider.id).cmd"
        $content = "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$launchScript`" $($provider.id) %*`r`n"
        Set-Content $shimPath -Value $content -Encoding ASCII
    }
}

# ---------------------------------------------------------------------------
# Ensure launchers\ is on the user PATH
# ---------------------------------------------------------------------------

function Add-LaunchersToPATH {
    $launchersDir = Join-Path $script:SwitcherDir 'launchers'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = if ($userPath) { $userPath -split ';' | Where-Object { $_ } } else { @() }
    $already = $parts | Where-Object { $_.TrimEnd('\') -ieq $launchersDir.TrimEnd('\') }
    if (-not $already) {
        $newPath = ($parts + $launchersDir) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        $env:Path = ($env:Path + ';' + $launchersDir)
        Write-Host "Added launchers to user PATH: $launchersDir"
    }
}

function Remove-LaunchersFromPATH {
    $launchersDir = Join-Path $script:SwitcherDir 'launchers'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { return }
    $parts = $userPath -split ';' | Where-Object { $_ }
    $newParts = $parts | Where-Object { $_.TrimEnd('\') -ine $launchersDir.TrimEnd('\') }
    if ($newParts.Count -lt $parts.Count) {
        [Environment]::SetEnvironmentVariable('Path', ($newParts -join ';'), 'User')
        Write-Host "Removed launchers from user PATH: $launchersDir"
    }
}
