$ErrorActionPreference = "Stop"

$switcherDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $switcherDir "ClaudeModelSwitchers.ps1"
$documents = [Environment]::GetFolderPath("MyDocuments")

$profilePaths = @(
    (Join-Path $documents "WindowsPowerShell\profile.ps1"),
    (Join-Path $documents "PowerShell\profile.ps1")
)

$blockStart = "# BEGIN Claude Code model switchers"
$blockEnd = "# END Claude Code model switchers"
$profileBlock = @"
$blockStart
. "$modulePath"
$blockEnd
"@

foreach ($profilePath in $profilePaths) {
    if (-not (Test-Path -LiteralPath $profilePath)) { continue }

    $content = Get-Content -LiteralPath $profilePath -Raw
    $escapedStart = [regex]::Escape($blockStart)
    $escapedEnd = [regex]::Escape($blockEnd)
    $pattern = "(?s)$escapedStart.*?$escapedEnd"

    # If the file contains only our block, it was created by a previous installer run.
    # Remove it rather than leaving a script file that triggers execution policy errors.
    $stripped = [regex]::Replace($content, $pattern, "").Trim()
    if ($content -match $pattern -and [string]::IsNullOrWhiteSpace($stripped)) {
        Remove-Item -LiteralPath $profilePath -Force
        Write-Host "Removed installer-created profile (no user content): $profilePath"
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

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
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

. $modulePath
Write-Host ""
Write-Host "Installed. Open a new PowerShell or Command Prompt window, then run claude-deepseek or claude-pro."
Write-Host "For this PowerShell window, the functions are already loaded."
