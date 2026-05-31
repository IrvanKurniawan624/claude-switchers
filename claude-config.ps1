# claude-config.ps1
# Interactive terminal menu for managing claude-switchers providers, API keys,
# and installation. Run directly: powershell -File claude-config.ps1
# Or via the claude-config command after installation.

. (Join-Path $PSScriptRoot 'ClaudeSwitch.Core.ps1')
Initialize-SwitcherConfig

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Header {
    Clear-Host
    Write-Host '╔══════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '║     Claude Code Provider Config          ║' -ForegroundColor Cyan
    Write-Host '╚══════════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host ''
}

function Write-ProviderTable {
    param([object]$Config)
    $i = 1
    Write-Host (' {0,-3} {1,-22} {2,-12} {3}' -f '#', 'Provider', 'Status', 'Key') -ForegroundColor Gray
    Write-Host (' {0,-3} {1,-22} {2,-12} {3}' -f '---', '----------------------', '----------', '----------') -ForegroundColor DarkGray
    foreach ($p in $Config.providers) {
        $status = if ($p.enabled) { 'enabled' } else { 'disabled' }
        $statusColor = if ($p.enabled) { 'Green' } else { 'DarkGray' }
        $keyStatus = if ($p.type -eq 'subscription') { '(subscription)' } elseif (-not [string]::IsNullOrWhiteSpace($p.apiKey)) { 'set' } else { 'NOT SET' }
        $keyColor = if ($keyStatus -eq 'NOT SET') { 'Yellow' } elseif ($keyStatus -eq 'set') { 'Green' } else { 'Gray' }
        Write-Host -NoNewline (' {0,-3} {1,-22} ' -f $i, $p.name)
        Write-Host -NoNewline ('{0,-12}' -f $status) -ForegroundColor $statusColor
        Write-Host (' {0}' -f $keyStatus) -ForegroundColor $keyColor
        $i++
    }
}

function Edit-EnvMapping {
    param([object]$Provider)
    Write-Host ''
    Write-Host "Current env overrides for $($Provider.name):" -ForegroundColor Cyan
    if ($Provider.env) {
        $Provider.env.PSObject.Properties | ForEach-Object {
            Write-Host "  $($_.Name) = $($_.Value)"
        }
    } else {
        Write-Host "  (none)"
    }
    Write-Host ''
    Write-Host "Enter KEY=VALUE to set, KEY= to clear, or leave blank to finish." -ForegroundColor Gray
    while ($true) {
        $line = Read-Host "env"
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        if ($line -match '^([A-Z0-9_]+)=(.*)$') {
            $k = $Matches[1]; $v = $Matches[2]
            if (-not $Provider.env) {
                $Provider | Add-Member -MemberType NoteProperty -Name 'env' -Value ([PSCustomObject]@{})
            }
            if ([string]::IsNullOrWhiteSpace($v)) {
                $Provider.env.PSObject.Properties.Remove($k)
                Write-Host "Cleared $k" -ForegroundColor DarkGray
            } else {
                if ($Provider.env.PSObject.Properties[$k]) {
                    $Provider.env.$k = $v
                } else {
                    $Provider.env | Add-Member -MemberType NoteProperty -Name $k -Value $v
                }
                Write-Host "Set $k = $v" -ForegroundColor Green
            }
        } else {
            Write-Host "Format: KEY=VALUE (use KEY= to clear)" -ForegroundColor Yellow
        }
    }
}

function Manage-Provider {
    param([object]$Config, [int]$Index)
    $provider = $Config.providers[$Index]

    while ($true) {
        Write-Header
        Write-Host "Provider: $($provider.name)" -ForegroundColor White
        Write-Host ''
        Write-Host "  t  toggle enabled (currently: $(if ($provider.enabled) { 'ENABLED' } else { 'DISABLED' }))" -ForegroundColor $(if ($provider.enabled) { 'Green' } else { 'DarkGray' })
        if ($provider.type -ne 'subscription') {
            Write-Host "  k  set API key"
            Write-Host "  c  clear API key"
            Write-Host "  u  edit base URL (currently: $($provider.baseUrl))"
            Write-Host "  e  edit model/env overrides"
        }
        Write-Host "  d  delete this provider"
        Write-Host "  b  back"
        Write-Host ''
        $choice = (Read-Host "Choice").Trim().ToLower()

        switch ($choice) {
            't' {
                $provider.enabled = -not $provider.enabled
                Write-Host "$(if ($provider.enabled) { 'Enabled' } else { 'Disabled' }) $($provider.name)." -ForegroundColor Cyan
                Start-Sleep 1
            }
            'k' {
                if ($provider.type -eq 'subscription') { Write-Host "N/A for subscription."; Start-Sleep 1; break }
                $key = Read-Host "Paste your API key (input hidden)" # Read-Host not SecureString so we can store it
                if (-not [string]::IsNullOrWhiteSpace($key)) {
                    $provider.apiKey = $key.Trim()
                    Write-Host "API key saved." -ForegroundColor Green
                } else {
                    Write-Host "No change." -ForegroundColor DarkGray
                }
                Start-Sleep 1
            }
            'c' {
                if ($provider.type -eq 'subscription') { Write-Host "N/A for subscription."; Start-Sleep 1; break }
                $provider.apiKey = ''
                Write-Host "API key cleared." -ForegroundColor Yellow
                Start-Sleep 1
            }
            'u' {
                if ($provider.type -eq 'subscription') { Write-Host "N/A for subscription."; Start-Sleep 1; break }
                $url = Read-Host "New base URL (current: $($provider.baseUrl))"
                if (-not [string]::IsNullOrWhiteSpace($url)) {
                    $provider.baseUrl = $url.Trim()
                    Write-Host "Base URL updated." -ForegroundColor Green
                }
                Start-Sleep 1
            }
            'e' {
                if ($provider.type -eq 'subscription') { Write-Host "N/A for subscription."; Start-Sleep 1; break }
                Edit-EnvMapping -Provider $provider
            }
            'd' {
                $confirm = Read-Host "Delete '$($provider.name)'? (yes/no)"
                if ($confirm.Trim().ToLower() -eq 'yes') {
                    $Config.providers = @($Config.providers | Where-Object { $_.id -ne $provider.id })
                    Write-Host "Deleted $($provider.name)." -ForegroundColor Yellow
                    Start-Sleep 1
                    return  # back to main menu
                }
            }
            'b' { return }
        }
    }
}

function Add-CustomProvider {
    param([object]$Config)
    Write-Header
    Write-Host "Add a custom provider" -ForegroundColor Cyan
    Write-Host ''

    $id = (Read-Host "Short ID (used in commands, e.g. 'myprovider')").Trim().ToLower() -replace '[^a-z0-9]', ''
    if ([string]::IsNullOrWhiteSpace($id)) { Write-Host "Cancelled."; Start-Sleep 1; return }

    $existing = $Config.providers | Where-Object { $_.id -eq $id }
    if ($existing) { Write-Host "ID '$id' already exists."; Start-Sleep 2; return }

    $name = (Read-Host "Display name (e.g. 'My Provider')").Trim()
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $id }

    $url = (Read-Host "Base URL (Anthropic-compatible endpoint)").Trim()
    if ([string]::IsNullOrWhiteSpace($url)) { Write-Host "Cancelled."; Start-Sleep 1; return }

    $apiKey = (Read-Host "API key (leave blank to set later)").Trim()

    $model = (Read-Host "Default model name (leave blank to skip)").Trim()

    $envObj = [PSCustomObject]@{
        'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC' = '1'
        'CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK' = '1'
        'CLAUDE_CODE_EFFORT_LEVEL'                  = 'max'
        'API_TIMEOUT_MS'                            = '600000'
    }
    if (-not [string]::IsNullOrWhiteSpace($model)) {
        $envObj | Add-Member -MemberType NoteProperty -Name 'ANTHROPIC_MODEL'                   -Value $model
        $envObj | Add-Member -MemberType NoteProperty -Name 'ANTHROPIC_DEFAULT_OPUS_MODEL'       -Value $model
        $envObj | Add-Member -MemberType NoteProperty -Name 'ANTHROPIC_DEFAULT_SONNET_MODEL'     -Value $model
        $envObj | Add-Member -MemberType NoteProperty -Name 'ANTHROPIC_DEFAULT_HAIKU_MODEL'      -Value $model
        $envObj | Add-Member -MemberType NoteProperty -Name 'CLAUDE_CODE_SUBAGENT_MODEL'         -Value $model
    }

    $newProvider = [PSCustomObject]@{
        id      = $id
        name    = $name
        type    = 'api'
        enabled = $true
        baseUrl = $url
        apiKey  = $apiKey
        env     = $envObj
    }

    $Config.providers = @($Config.providers) + $newProvider
    Write-Host "Added '$name' (claude-$id)." -ForegroundColor Green
    Start-Sleep 2
}

function Run-Uninstall {
    Write-Header
    Write-Host "Uninstall claude-switchers" -ForegroundColor Yellow
    Write-Host ''
    Write-Host "This will:"
    Write-Host "  - Remove the claude-switchers block from your PowerShell profiles"
    Write-Host "  - Remove the switchers folder and launchers\\ from user PATH"
    Write-Host "  - Delete launchers\\*.cmd, config.json, and .env"
    Write-Host ''
    $confirm = Read-Host "Type 'uninstall' to confirm, or press Enter to cancel"
    if ($confirm.Trim().ToLower() -ne 'uninstall') {
        Write-Host "Cancelled." -ForegroundColor DarkGray
        Start-Sleep 1
        return
    }

    $switcherDir = $script:SwitcherDir
    $documents = [Environment]::GetFolderPath('MyDocuments')
    $profilePaths = @(
        (Join-Path $documents 'WindowsPowerShell\profile.ps1'),
        (Join-Path $documents 'PowerShell\profile.ps1')
    )
    $blockStart = '# BEGIN Claude Code model switchers'
    $blockEnd   = '# END Claude Code model switchers'

    foreach ($profilePath in $profilePaths) {
        if (-not (Test-Path -LiteralPath $profilePath)) { continue }
        $content = Get-Content -LiteralPath $profilePath -Raw
        $escapedStart = [regex]::Escape($blockStart)
        $escapedEnd   = [regex]::Escape($blockEnd)
        $pattern = "(?s)\r?\n?[ \t]*$escapedStart.*?$escapedEnd[ \t]*\r?\n?"
        if ($content -match $pattern) {
            $trimmed = [regex]::Replace($content, $pattern, '').Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) {
                Remove-Item -LiteralPath $profilePath -Force
                Write-Host "Removed installer-created profile: $profilePath" -ForegroundColor DarkGray
            } else {
                Set-Content -LiteralPath $profilePath -Value ($trimmed + [Environment]::NewLine) -Encoding UTF8
                Write-Host "Removed Claude switchers block from: $profilePath" -ForegroundColor DarkGray
            }
        }
    }

    # Remove switcher folder and launchers\ from PATH
    $launchersDir = Join-Path $switcherDir 'launchers'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath) {
        $parts    = $userPath -split ';' | Where-Object { $_ }
        $newParts = $parts | Where-Object {
            $_.TrimEnd('\') -ine $switcherDir.TrimEnd('\') -and
            $_.TrimEnd('\') -ine $launchersDir.TrimEnd('\')
        }
        if ($newParts.Count -lt $parts.Count) {
            [Environment]::SetEnvironmentVariable('Path', ($newParts -join ';'), 'User')
            Write-Host "Removed from user PATH." -ForegroundColor DarkGray
        }
    }

    # Delete generated files
    foreach ($target in @(
        (Join-Path $switcherDir 'config.json'),
        (Join-Path $switcherDir '.env')
    )) {
        if (Test-Path $target) { Remove-Item $target -Force; Write-Host "Deleted: $target" -ForegroundColor DarkGray }
    }
    if (Test-Path $launchersDir) {
        Get-ChildItem $launchersDir -Filter '*.cmd' | Remove-Item -Force
        Write-Host "Cleared launchers\." -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host "Uninstalled. Open a new terminal to confirm. The repo folder was not deleted." -ForegroundColor Green
    Write-Host "Press Enter to exit." -ForegroundColor Gray
    Read-Host | Out-Null
    exit 0
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

while ($true) {
    $config = Get-SwitcherConfig
    if (-not $config) {
        Write-Error "Could not load config. Ensure config.example.json is present."
        exit 1
    }

    Write-Header
    Write-ProviderTable -Config $config
    Write-Host ''
    Write-Host "  [number]  manage provider" -ForegroundColor Gray
    Write-Host "  a         add custom provider" -ForegroundColor Gray
    Write-Host "  r         regenerate CMD launch commands" -ForegroundColor Gray
    Write-Host "  u         uninstall claude-switchers" -ForegroundColor Gray
    Write-Host "  q         save and quit" -ForegroundColor Gray
    Write-Host ''
    $choice = (Read-Host "Choice").Trim().ToLower()

    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $config.providers.Count) {
            Manage-Provider -Config $config -Index $idx
            Save-SwitcherConfig $config
            Update-ClaudeLaunchers
        } else {
            Write-Host "Invalid number." -ForegroundColor Yellow
            Start-Sleep 1
        }
    } else {
        switch ($choice) {
            'a' {
                Add-CustomProvider -Config $config
                Save-SwitcherConfig $config
                Update-ClaudeLaunchers
            }
            'r' {
                Update-ClaudeLaunchers
                Write-Host "CMD launch commands regenerated." -ForegroundColor Green
                Start-Sleep 1
            }
            'u' { Run-Uninstall }
            'q' {
                Save-SwitcherConfig $config
                Update-ClaudeLaunchers
                Write-Host "Saved. Restart your terminal for new commands to take effect." -ForegroundColor Cyan
                break
            }
            default {
                Write-Host "Unknown choice." -ForegroundColor Yellow
                Start-Sleep 1
            }
        }
        if ($choice -eq 'q') { break }
    }
}
