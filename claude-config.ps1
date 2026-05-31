# claude-config.ps1
# Interactive terminal menu for managing claude-switchers.
# Run via: claude-config

. (Join-Path $PSScriptRoot 'ClaudeSwitch.Core.ps1')
Initialize-SwitcherConfig

# Invoke-Menu is defined in ClaudeSwitch.Core.ps1 (dot-sourced above).

# Simple Yes/No confirmation using arrow keys.
function Confirm-Action {
    param([string]$Message, [bool]$Default = $false)
    Write-Host ''
    Write-Host "  $Message" -ForegroundColor Yellow
    $items = @('No, cancel', 'Yes, confirm')
    $result = Invoke-Menu -Items $items -Default $(if ($Default) { 1 } else { 0 })
    return ($result -eq 1)
}

# ---------------------------------------------------------------------------
# Provider management submenu
# ---------------------------------------------------------------------------
function Manage-Provider {
    param([object]$Config, [int]$Index)
    $p = $Config.providers[$Index]

    while ($true) {
        Clear-Host
        Write-Host ''
        Write-Host "  ===========================================" -ForegroundColor Cyan
        Write-Host "    Provider: $($p.name)" -ForegroundColor Cyan
        Write-Host "  ===========================================" -ForegroundColor Cyan

        $toggleLabel = "Toggle  (currently: $(if ($p.enabled) { 'ENABLED' } else { 'DISABLED' }))"

        $items = @($toggleLabel)

        if ($p.type -ne 'subscription') {
            $keyLabel = if ([string]::IsNullOrWhiteSpace($p.apiKey)) { 'Set API key  (not set)' } else { 'Set API key  (already set)' }
            $items += @('--', $keyLabel, 'Clear API key', "Edit base URL  ($($p.baseUrl))", 'Edit model / env overrides')
        }

        $items += @('--', 'Delete this provider', '--', 'Back')

        $sel = Invoke-Menu -Items $items
        if ($sel -lt 0) { return }

        $chosen = $items[$sel]

        if ($chosen -eq $toggleLabel) {
            $p.enabled = -not $p.enabled
            Write-Host "  $(if ($p.enabled) { 'Enabled' } else { 'Disabled' }) $($p.name)." -ForegroundColor Cyan
            Start-Sleep 1

        } elseif ($chosen -like 'Set API key*') {
            Write-Host ''
            $k = Read-Host "  Paste API key"
            if (-not [string]::IsNullOrWhiteSpace($k)) {
                $p.apiKey = $k.Trim()
                Write-Host "  Key saved." -ForegroundColor Green
                Write-Host ''
                $testSel = Invoke-Menu -Items @('Skip test', 'Test key now') -Default 1
                if ($testSel -eq 1) {
                    $ok = Test-ProviderKey -BaseUrl $p.baseUrl -ApiKey $p.apiKey
                    if (-not $ok) {
                        Write-Host '  Key saved anyway — fix it here if needed.' -ForegroundColor DarkGray
                    }
                    Start-Sleep 2
                }
            } else {
                Write-Host "  No change." -ForegroundColor DarkGray
                Start-Sleep 1
            }

        } elseif ($chosen -eq 'Clear API key') {
            if (Confirm-Action "Clear the API key for '$($p.name)'?") {
                $p.apiKey = ''
                Write-Host "  Key cleared." -ForegroundColor Yellow
                Start-Sleep 1
            }

        } elseif ($chosen -like 'Edit base URL*') {
            Write-Host ''
            $url = Read-Host "  New base URL (current: $($p.baseUrl))"
            if (-not [string]::IsNullOrWhiteSpace($url)) {
                $p.baseUrl = $url.Trim()
                Write-Host "  Updated." -ForegroundColor Green
                Start-Sleep 1
            }

        } elseif ($chosen -eq 'Edit model / env overrides') {
            Edit-EnvMapping -Provider $p

        } elseif ($chosen -eq 'Delete this provider') {
            if (Confirm-Action "Delete '$($p.name)' permanently?") {
                $Config.providers = @($Config.providers | Where-Object { $_.id -ne $p.id })
                Write-Host "  Deleted." -ForegroundColor Yellow
                Start-Sleep 1
                return
            }

        } elseif ($chosen -eq 'Back') {
            return
        }
    }
}

# ---------------------------------------------------------------------------
# Env/model mapping editor (text-input, no arrow needed)
# ---------------------------------------------------------------------------
function Edit-EnvMapping {
    param([object]$Provider)
    Clear-Host
    Write-Host ''
    Write-Host "  Env overrides for $($Provider.name)" -ForegroundColor Cyan
    Write-Host "  Enter KEY=VALUE to set, KEY= to clear, blank line to finish." -ForegroundColor Gray
    Write-Host ''

    if ($Provider.env) {
        $Provider.env.PSObject.Properties | ForEach-Object {
            Write-Host "    $($_.Name) = $($_.Value)" -ForegroundColor DarkGray
        }
    }
    Write-Host ''

    while ($true) {
        $line = Read-Host "  env"
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        if ($line -match '^([A-Z0-9_]+)=(.*)$') {
            $k = $Matches[1]; $v = $Matches[2]
            if (-not $Provider.env) {
                $Provider | Add-Member -MemberType NoteProperty -Name 'env' -Value ([PSCustomObject]@{})
            }
            if ([string]::IsNullOrWhiteSpace($v)) {
                $Provider.env.PSObject.Properties.Remove($k)
                Write-Host "  Cleared $k" -ForegroundColor DarkGray
            } else {
                if ($Provider.env.PSObject.Properties[$k]) { $Provider.env.$k = $v }
                else { $Provider.env | Add-Member -MemberType NoteProperty -Name $k -Value $v }
                Write-Host "  Set $k = $v" -ForegroundColor Green
            }
        } else {
            Write-Host "  Format: KEY=VALUE  or  KEY= to clear" -ForegroundColor Yellow
        }
    }
}

# ---------------------------------------------------------------------------
# Add custom provider (text-input flow)
# ---------------------------------------------------------------------------
function Add-CustomProvider {
    param([object]$Config)
    Clear-Host
    Write-Host ''
    Write-Host "  ===========================================" -ForegroundColor Cyan
    Write-Host "    Add custom provider" -ForegroundColor Cyan
    Write-Host "  ===========================================" -ForegroundColor Cyan
    Write-Host ''

    $id = (Read-Host "  Short ID  (e.g. myprovider)").Trim().ToLower() -replace '[^a-z0-9]', ''
    if ([string]::IsNullOrWhiteSpace($id)) { return }

    if ($Config.providers | Where-Object { $_.id -eq $id }) {
        Write-Host "  ID '$id' already exists." -ForegroundColor Yellow; Start-Sleep 2; return
    }

    $name    = (Read-Host "  Display name  (e.g. My Provider)").Trim()
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $id }

    $url     = (Read-Host "  Base URL  (Anthropic-compatible endpoint)").Trim()
    if ([string]::IsNullOrWhiteSpace($url)) { Write-Host "  Cancelled."; Start-Sleep 1; return }

    $apiKey  = (Read-Host "  API key  (leave blank to set later)").Trim()
    $model   = (Read-Host "  Default model name  (leave blank to skip)").Trim()

    $envObj = [PSCustomObject]@{
        'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC'  = '1'
        'CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK' = '1'
        'CLAUDE_CODE_EFFORT_LEVEL'                  = 'max'
        'API_TIMEOUT_MS'                            = '600000'
    }
    if (-not [string]::IsNullOrWhiteSpace($model)) {
        foreach ($k in @('ANTHROPIC_MODEL','ANTHROPIC_DEFAULT_OPUS_MODEL','ANTHROPIC_DEFAULT_SONNET_MODEL','ANTHROPIC_DEFAULT_HAIKU_MODEL','CLAUDE_CODE_SUBAGENT_MODEL')) {
            $envObj | Add-Member -MemberType NoteProperty -Name $k -Value $model
        }
    }

    $Config.providers = @($Config.providers) + [PSCustomObject]@{
        id = $id; name = $name; type = 'api'; enabled = $true
        baseUrl = $url; apiKey = $apiKey; env = $envObj
    }

    Write-Host ''
    Write-Host "  Added '$name' -> command: claude-$id" -ForegroundColor Green
    Start-Sleep 2
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
function Run-Uninstall {
    Clear-Host
    Write-Host ''
    Write-Host "  ===========================================" -ForegroundColor Yellow
    Write-Host "    Uninstall claude-switchers" -ForegroundColor Yellow
    Write-Host "  ===========================================" -ForegroundColor Yellow
    Write-Host ''
    Write-Host "  This will remove:" -ForegroundColor Gray
    Write-Host "    - Claude switchers block from PowerShell profiles" -ForegroundColor Gray
    Write-Host "    - Switcher folder and launchers\ from user PATH" -ForegroundColor Gray
    Write-Host "    - launchers\, config.json, and .env" -ForegroundColor Gray
    Write-Host ''

    if (-not (Confirm-Action 'Proceed with uninstall?')) {
        return
    }

    $switcherDir  = $script:SwitcherDir
    $launchersDir = Join-Path $switcherDir 'launchers'
    $documents    = [Environment]::GetFolderPath('MyDocuments')
    $blockStart   = '# BEGIN Claude Code model switchers'
    $blockEnd     = '# END Claude Code model switchers'

    foreach ($profilePath in @(
        (Join-Path $documents 'WindowsPowerShell\profile.ps1'),
        (Join-Path $documents 'PowerShell\profile.ps1')
    )) {
        if (-not (Test-Path -LiteralPath $profilePath)) { continue }
        $content = Get-Content -LiteralPath $profilePath -Raw
        $pattern = "(?s)\r?\n?[ \t]*$([regex]::Escape($blockStart)).*?$([regex]::Escape($blockEnd))[ \t]*\r?\n?"
        if ($content -match $pattern) {
            $trimmed = [regex]::Replace($content, $pattern, '').Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) {
                Remove-Item -LiteralPath $profilePath -Force
                Write-Host "  Removed: $profilePath" -ForegroundColor DarkGray
            } else {
                Set-Content -LiteralPath $profilePath -Value ($trimmed + [Environment]::NewLine) -Encoding UTF8
                Write-Host "  Patched: $profilePath" -ForegroundColor DarkGray
            }
        }
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath) {
        $parts    = $userPath -split ';' | Where-Object { $_ }
        $newParts = $parts | Where-Object {
            $_.TrimEnd('\') -ine $switcherDir.TrimEnd('\') -and
            $_.TrimEnd('\') -ine $launchersDir.TrimEnd('\')
        }
        if ($newParts.Count -lt $parts.Count) {
            [Environment]::SetEnvironmentVariable('Path', ($newParts -join ';'), 'User')
            Write-Host "  Removed from PATH." -ForegroundColor DarkGray
        }
    }

    foreach ($f in @((Join-Path $switcherDir 'config.json'), (Join-Path $switcherDir '.env'))) {
        if (Test-Path $f) { Remove-Item $f -Force; Write-Host "  Deleted: $f" -ForegroundColor DarkGray }
    }
    if (Test-Path $launchersDir) {
        Get-ChildItem $launchersDir -Filter '*.cmd' | Remove-Item -Force
        Write-Host "  Cleared: launchers\" -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host "  Done. Open a new terminal to confirm." -ForegroundColor Green
    Write-Host "  (The repo folder was not deleted.)" -ForegroundColor Gray
    Write-Host ''
    Write-Host "  Press any key to exit..." -ForegroundColor DarkGray
    $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') | Out-Null
    exit 0
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
while ($true) {
    $config = Get-SwitcherConfig
    if (-not $config) { Write-Error 'Cannot load config.'; exit 1 }

    Clear-Host
    Write-Host ''
    Write-Host "  ===========================================" -ForegroundColor Cyan
    Write-Host "    Claude Code Provider Config" -ForegroundColor Cyan
    Write-Host "  ===========================================" -ForegroundColor Cyan
    Write-Host ''

    # Build flat item list: providers + action entries
    $menuItems   = @()
    $providerMap = @{}   # menuIndex -> providerIndex

    for ($i = 0; $i -lt $config.providers.Count; $i++) {
        $p         = $config.providers[$i]
        $status    = if ($p.enabled) { 'enabled ' } else { 'disabled' }
        $keyStatus = if ($p.type -eq 'subscription') { '(subscription)' } elseif (-not [string]::IsNullOrWhiteSpace($p.apiKey)) { 'key: set' } else { 'key: NOT SET' }
        $label     = '{0,-24} {1,-10} {2}' -f $p.name, $status, $keyStatus
        $providerMap[$menuItems.Count] = $i
        $menuItems += $label
    }

    $menuItems   += '--'
    $addIdx       = $menuItems.Count; $menuItems += 'Add custom provider'
    $regenIdx     = $menuItems.Count; $menuItems += 'Regenerate CMD commands'
    $uninstallIdx = $menuItems.Count; $menuItems += 'Uninstall'
    $quitIdx      = $menuItems.Count; $menuItems += 'Save & quit'

    $sel = Invoke-Menu -Items $menuItems

    if ($sel -lt 0 -or $sel -eq $quitIdx) {
        Save-SwitcherConfig $config
        Update-ClaudeLaunchers
        Write-Host "  Saved. Restart your terminal for new commands to take effect." -ForegroundColor Cyan
        break
    } elseif ($providerMap.ContainsKey($sel)) {
        Manage-Provider -Config $config -Index $providerMap[$sel]
        Save-SwitcherConfig $config
        Update-ClaudeLaunchers
    } elseif ($sel -eq $addIdx) {
        Add-CustomProvider -Config $config
        Save-SwitcherConfig $config
        Update-ClaudeLaunchers
    } elseif ($sel -eq $regenIdx) {
        Update-ClaudeLaunchers
        Write-Host "  CMD launch commands regenerated." -ForegroundColor Green
        Start-Sleep 1
    } elseif ($sel -eq $uninstallIdx) {
        Run-Uninstall
    }
}
