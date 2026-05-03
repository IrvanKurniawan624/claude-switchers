$_envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $_envFile) {
    Get-Content $_envFile | Where-Object { $_ -match '^\s*[^#=\s]' } | ForEach-Object {
        $parts = $_ -split '=', 2
        if ($parts.Count -eq 2) {
            $k = $parts[0].Trim(); $v = $parts[1].Trim()
            if (-not [System.Environment]::GetEnvironmentVariable($k)) {
                [System.Environment]::SetEnvironmentVariable($k, $v, 'Process')
            }
        }
    }
}
