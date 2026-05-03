$ErrorActionPreference = "Stop"

$switcherDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$documents = [Environment]::GetFolderPath("MyDocuments")

$profilePaths = @(
    (Join-Path $documents "WindowsPowerShell\profile.ps1"),
    (Join-Path $documents "PowerShell\profile.ps1")
)

$blockStart = "# BEGIN Claude Code model switchers"
$blockEnd = "# END Claude Code model switchers"

foreach ($profilePath in $profilePaths) {
    if (-not (Test-Path -LiteralPath $profilePath)) {
        Write-Host "No profile found at: $profilePath (skipping)"
        continue
    }

    $content = Get-Content -LiteralPath $profilePath -Raw
    $escapedStart = [regex]::Escape($blockStart)
    $escapedEnd = [regex]::Escape($blockEnd)
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

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not [string]::IsNullOrWhiteSpace($userPath)) {
    $pathParts = $userPath -split ";" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $newParts = $pathParts | Where-Object { $_.TrimEnd("\") -ine $switcherDir.TrimEnd("\") }

    if ($newParts.Count -lt $pathParts.Count) {
        $newPath = $newParts -join ";"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path = ($env:Path -split ";" | Where-Object { $_.TrimEnd("\") -ine $switcherDir.TrimEnd("\") }) -join ";"
        Write-Host "Removed from user PATH: $switcherDir"
    } else {
        Write-Host "Not found in user PATH: $switcherDir (skipping)"
    }
}

$envFile = Join-Path $switcherDir ".env"
if (Test-Path -LiteralPath $envFile) {
    Remove-Item -LiteralPath $envFile -Force
    Write-Host "Deleted .env file."
} else {
    Write-Host "No .env file found (skipping)."
}

Write-Host ""
Write-Host "Uninstalled. Open a new terminal to confirm the changes take effect."
