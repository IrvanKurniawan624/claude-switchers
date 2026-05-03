@echo off
if exist "%~dp0.env" (
  for /f "usebackq tokens=1,* delims==" %%A in ("%~dp0.env") do (
    if not "%%A"=="" if not "%%A:~0,1%"=="#" (
      if not defined %%A set "%%A=%%B"
    )
  )
)
if "%DEEPSEEK_API_KEY%"=="" (
  echo DEEPSEEK_API_KEY is not set.
  echo.
  echo Set it for this session, then re-run:
  echo   PowerShell:  $env:DEEPSEEK_API_KEY='your-key'
  echo   CMD:         set DEEPSEEK_API_KEY=your-key
  echo.
  echo Or add it permanently to .env in the claude-switchers folder.
  exit /b 1
)

set "ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic"
set "ANTHROPIC_AUTH_TOKEN=%DEEPSEEK_API_KEY%"
set "ANTHROPIC_API_KEY="
set "ANTHROPIC_MODEL=deepseek-v4-pro[1m]"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-pro"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash"
set "CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-pro"
set "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
set "CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK=1"
set "CLAUDE_CODE_EFFORT_LEVEL=max"
set "API_TIMEOUT_MS=600000"

echo Claude Code session is set to DeepSeek: deepseek-v4-pro[1m], effort=max.
claude %*
