# claude-launch.ps1
# Non-interactive entry point used by generated CMD shims.
# Usage: claude-launch.ps1 <provider-id> [claude args...]
param(
    [Parameter(Position = 0, Mandatory)][string]$Id,
    [Parameter(Position = 1, ValueFromRemainingArguments)][string[]]$Rest
)

. (Join-Path $PSScriptRoot 'ClaudeSwitch.Core.ps1')
Initialize-SwitcherConfig
Invoke-ClaudeProvider -Id $Id -Rest $Rest
