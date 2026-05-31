$ErrorActionPreference = "Stop"

$switcherDir  = $PSScriptRoot
$modulePath   = Join-Path $switcherDir "ClaudeModelSwitchers.ps1"
$launchersDir = Join-Path $switcherDir "launchers"
$documents    = [Environment]::GetFolderPath("MyDocuments")

$profilePaths = @(
    (Join-Path $documents "WindowsPowerShell\profile.ps1"),
    (Join-Path $documents "PowerShell\profile.ps1")
)

$blockStart = "# BEGIN Claude Code model switchers"
$blockEnd   = "# END Claude Code model switchers"
$profileBlock = @"
$blockStart
. "$modulePath"
$blockEnd
"@

# ── 1. Patch PowerShell profiles ────────────────────────────────────────────
foreach ($profilePath in $profilePaths) {
    if (-not (Test-Path -LiteralPath $profilePath)) {
        Write-Host "No profile found at: $profilePath"
        Write-Host "  To create it and re-run, paste this command:"
        Write-Host "    New-Item -Path '$profilePath' -ItemType File -Force; powershell -ExecutionPolicy Bypass -File '$(Join-Path $switcherDir 'install-switchers.ps1')'"
        continue
    }

    $content = Get-Content -LiteralPath $profilePath -Raw
    $escapedStart = [regex]::Escape($blockStart)
    $escapedEnd   = [regex]::Escape($blockEnd)
    $pattern      = "(?s)$escapedStart.*?$escapedEnd"

    $stripped = [regex]::Replace($content, $pattern, "").Trim()
    if ($content -match $pattern -and [string]::IsNullOrWhiteSpace($stripped)) {
        # Profile contains only our block — overwrite with updated block instead of deleting
        Set-Content -LiteralPath $profilePath -Value $profileBlock -Encoding UTF8
        Write-Host "Updated PowerShell profile: $profilePath"
        continue
    }

    if ($content -match $pattern) {
        $content = [regex]::Replace($content, $pattern, $profileBlock)
    } elseif ([string]::IsNullOrWhiteSpace($content)) {
        $content = $profileBlock
    } else {
        $content = $content.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $profileBlock
    }

    Set-Content -LiteralPath $profilePath -Value $content -Encoding UTF8
    Write-Host "Updated PowerShell profile: $profilePath"
}

# ── 2. Add switcher folder to user PATH (for static .cmd shims) ─────────────
$userPath  = [Environment]::GetEnvironmentVariable("Path", "User")
$pathParts = @()
if (-not [string]::IsNullOrWhiteSpace($userPath)) {
    $pathParts = $userPath -split ";" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

$alreadyInPath = $pathParts | Where-Object { $_.TrimEnd("\") -ieq $switcherDir.TrimEnd("\") }
if (-not $alreadyInPath) {
    $newPath = (($pathParts + $switcherDir) -join ";")
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = (($env:Path -split ";" | Where-Object { $_ }) + $switcherDir) -join ";"
    Write-Host "Added to user PATH: $switcherDir"
} else {
    Write-Host "Already in user PATH: $switcherDir"
}

# ── 3. Add launchers\ to user PATH (for per-provider .cmd shims) ────────────
$alreadyLaunchers = $pathParts | Where-Object { $_.TrimEnd("\") -ieq $launchersDir.TrimEnd("\") }
if (-not $alreadyLaunchers) {
    $userPath2 = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts2    = $userPath2 -split ";" | Where-Object { $_ }
    $newPath2  = ($parts2 + $launchersDir) -join ";"
    [Environment]::SetEnvironmentVariable("Path", $newPath2, "User")
    $env:Path = ($env:Path + ";" + $launchersDir)
    Write-Host "Added to user PATH: $launchersDir"
} else {
    Write-Host "Already in user PATH: $launchersDir"
}

# ── 4. Init config.json and migrate legacy .env ─────────────────────────────
. $modulePath        # dot-source so core functions are available in this session
Initialize-SwitcherConfig
Write-Host "Config initialised."

# ── 5. Generate per-provider CMD shims ──────────────────────────────────────
Update-ClaudeLaunchers
Write-Host "Launch commands generated in: $launchersDir"

Write-Host ""
Write-Host "=========================================="  -ForegroundColor Green
Write-Host "  Installation complete!"                    -ForegroundColor Green
Write-Host "=========================================="  -ForegroundColor Green
Write-Host ""
Write-Host "  IMPORTANT: Open a NEW terminal window"    -ForegroundColor Yellow
Write-Host "  for the commands to become available."    -ForegroundColor Yellow
Write-Host ""
Write-Host "  Then run:"                                -ForegroundColor Cyan
Write-Host "    claude-config    -- manage providers and API keys"
Write-Host "    claude-pro       -- launch with Claude Pro subscription"
Write-Host "    claude-deepseek  -- launch with DeepSeek"
Write-Host "    claude-switch    -- pick a provider interactively"
Write-Host ""
