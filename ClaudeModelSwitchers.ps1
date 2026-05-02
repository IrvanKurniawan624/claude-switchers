function Set-ClaudeDeepSeek {
    param(
        [string]$ApiKey = $env:DEEPSEEK_API_KEY,
        [switch]$NoLaunch,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$ClaudeArgs
    )

    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        Write-Host "DEEPSEEK_API_KEY is not set. Run: `$env:DEEPSEEK_API_KEY='your-key'"
        return
    }

    $env:DEEPSEEK_API_KEY = $ApiKey
    $env:ANTHROPIC_BASE_URL = "https://api.deepseek.com/anthropic"
    $env:ANTHROPIC_AUTH_TOKEN = $ApiKey
    Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue

    $env:ANTHROPIC_MODEL = "deepseek-v4-pro[1m]"
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL = "deepseek-v4-pro"
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL = "deepseek-v4-pro"
    $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "deepseek-v4-flash"
    $env:CLAUDE_CODE_SUBAGENT_MODEL = "deepseek-v4-pro"
    $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
    $env:CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK = "1"
    $env:CLAUDE_CODE_EFFORT_LEVEL = "max"
    $env:API_TIMEOUT_MS = "600000"

    Write-Host "Claude Code session is set to DeepSeek: deepseek-v4-pro[1m], effort=max."
    if (-not $NoLaunch) {
        claude @ClaudeArgs
    }
}

function Set-ClaudePro {
    param(
        [switch]$NoLaunch,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$ClaudeArgs
    )

    Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_MODEL -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_DEFAULT_OPUS_MODEL -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_DEFAULT_SONNET_MODEL -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_DEFAULT_HAIKU_MODEL -ErrorAction SilentlyContinue
    Remove-Item Env:CLAUDE_CODE_SUBAGENT_MODEL -ErrorAction SilentlyContinue
    Remove-Item Env:CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK -ErrorAction SilentlyContinue
    Remove-Item Env:CLAUDE_CODE_EFFORT_LEVEL -ErrorAction SilentlyContinue
    Remove-Item Env:API_TIMEOUT_MS -ErrorAction SilentlyContinue

    Write-Host "Claude Code session is set to Claude Pro/subscription defaults."
    if (-not $NoLaunch) {
        claude @ClaudeArgs
    }
}

Set-Alias claude-deepseek Set-ClaudeDeepSeek
Set-Alias claude-pro Set-ClaudePro
