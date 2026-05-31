$ErrorActionPreference = "Stop"

# TIP: You can also uninstall through the interactive menu:
#   claude-config  →  u (uninstall)

$switcherDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$launchersDir = Join-Path $switcherDir "launchers"
$documents    = [Environment]::GetFolderPath("MyDocuments")

$profilePaths = @(
    (Join-Path $documents "WindowsPowerShell\profile.ps1"),
    (Join-Path $documents "PowerShell\profile.ps1")
)

$blockStart = "# BEGIN Claude Code model switchers"
$blockEnd   = "# END Claude Code model switchers"

# ── 1. Remove profile patches ────────────────────────────────────────────────
foreach ($profilePath in $profilePaths) {
    if (-not (Test-Path -LiteralPath $profilePath)) {
        Write-Host "No profile found at: $profilePath (skipping)"
        continue
    }

    $content = Get-Content -LiteralPath $profilePath -Raw
    $escapedStart = [regex]::Escape($blockStart)
    $escapedEnd   = [regex]::Escape($blockEnd)
    $pattern = "(?s)\r?\n?[ \t]*$escapedStart.*?$escapedEnd[ \t]*\r?\n?"

    if ($content -match $pattern) {
        $trimmed = [regex]::Replace($content, $pattern, "").Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            Remove-Item -LiteralPath $profilePath -Force
            Write-Host "Removed installer-created profile: $profilePath"
        } else {
            Set-Content -LiteralPath $profilePath -Value ($trimmed + [Environment]::NewLine) -Encoding UTF8
            Write-Host "Removed Claude switchers block from: $profilePath"
        }
    } else {
        Write-Host "No Claude switchers block found in: $profilePath (skipping)"
    }
}

# ── 2. Remove switcherDir and launchersDir from user PATH ───────────────────
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not [string]::IsNullOrWhiteSpace($userPath)) {
    $parts    = $userPath -split ";" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $newParts = $parts | Where-Object {
        $_.TrimEnd("\") -ine $switcherDir.TrimEnd("\") -and
        $_.TrimEnd("\") -ine $launchersDir.TrimEnd("\")
    }
    if ($newParts.Count -lt $parts.Count) {
        [Environment]::SetEnvironmentVariable("Path", ($newParts -join ";"), "User")
        $env:Path = ($env:Path -split ";" | Where-Object {
            $_.TrimEnd("\") -ine $switcherDir.TrimEnd("\") -and
            $_.TrimEnd("\") -ine $launchersDir.TrimEnd("\")
        }) -join ";"
        Write-Host "Removed from user PATH."
    } else {
        Write-Host "Paths not found in user PATH (skipping)."
    }
}

# ── 3. Delete generated/config files ─────────────────────────────────────────
foreach ($target in @(
    (Join-Path $switcherDir "config.json"),
    (Join-Path $switcherDir ".env")
)) {
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Force
        Write-Host "Deleted: $target"
    } else {
        Write-Host "Not found (skipping): $target"
    }
}

if (Test-Path $launchersDir) {
    Get-ChildItem $launchersDir -Filter "*.cmd" | Remove-Item -Force
    Write-Host "Cleared launchers\."
} else {
    Write-Host "No launchers\\ folder found (skipping)."
}

Write-Host ""
Write-Host "Uninstalled. Open a new terminal to confirm the changes take effect."
Write-Host "The repo folder itself was not deleted — remove it manually if you no longer need it."
