# Claude Code Model Switchers

Switch [Claude Code](https://claude.ai/code) between your **Claude Pro subscription** and **DeepSeek** (via the DeepSeek API) without touching any config files — just run a single command per session.

---

## How It Works

Claude Code reads model identity and API routing from environment variables. This tool provides two commands that set or clear those variables before launching `claude`:

| Command | What it does |
|---|---|
| `claude-pro` | Clears all override env vars so Claude Code uses your default Claude Pro subscription |
| `claude-deepseek` | Sets `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and model overrides to route Claude Code through the DeepSeek API |

The variables that get toggled:

```
ANTHROPIC_BASE_URL
ANTHROPIC_AUTH_TOKEN
ANTHROPIC_API_KEY
ANTHROPIC_MODEL
ANTHROPIC_DEFAULT_OPUS_MODEL
ANTHROPIC_DEFAULT_SONNET_MODEL
ANTHROPIC_DEFAULT_HAIKU_MODEL
CLAUDE_CODE_SUBAGENT_MODEL
CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK
CLAUDE_CODE_EFFORT_LEVEL
API_TIMEOUT_MS
```

These are **session-scoped** — closing the terminal resets everything. No global config is modified by running these commands.

---

## Files

| File | Description |
|---|---|
| `ClaudeModelSwitchers.ps1` | PowerShell functions (`claude-pro`, `claude-deepseek`) |
| `claude-pro.cmd` | Command Prompt equivalent for `claude-pro` |
| `claude-deepseek.cmd` | Command Prompt equivalent for `claude-deepseek` |
| `install-switchers.ps1` | One-time installer: patches PowerShell profiles and adds folder to user `PATH` |

---

## Installation

### Step 1 — Clone or copy this folder

Place the folder anywhere on your system, for example:

```
C:\Users\YourName\claude-switchers
```

### Step 2 — Set your DeepSeek API key

Store your key as a persistent environment variable so you don't have to set it every session.

**PowerShell (sets it permanently for your user):**
```powershell
[Environment]::SetEnvironmentVariable("DEEPSEEK_API_KEY", "<DeepSeek API>", "User")
```

**Or temporarily for the current session only:**
```powershell
$env:DEEPSEEK_API_KEY = "<DeepSeek API>"
```

Get your API key from [platform.deepseek.com](https://platform.deepseek.com/).

### Step 3 — Run the installer

Open PowerShell and run:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\path\to\claude-switchers\install-switchers.ps1"
```

The installer does two things automatically:
1. **Patches your PowerShell profiles** — adds a dot-source line so `claude-pro` and `claude-deepseek` are available in every new PowerShell window
2. **Adds the folder to your user `PATH`** — so `claude-pro.cmd` and `claude-deepseek.cmd` work from Command Prompt too

Profiles patched:

| Profile file | Used by |
|---|---|
| `Documents\WindowsPowerShell\profile.ps1` | Windows PowerShell 5.x |
| `Documents\PowerShell\profile.ps1` | PowerShell 7+ (pwsh) |

The installer wraps its changes in a clearly marked block so it can update the path safely if you ever move the folder:

```powershell
# BEGIN Claude Code model switchers
. "C:\path\to\claude-switchers\ClaudeModelSwitchers.ps1"
# END Claude Code model switchers
```

> **If you move the folder later**, just re-run the installer from the new location — it will replace the old path in both profiles automatically.

### Step 4 — Open a new terminal

The profile changes take effect in any new PowerShell or Command Prompt window.

---

## Usage

### PowerShell

```powershell
# Use Claude Pro (subscription)
claude-pro

# Use DeepSeek (requires DEEPSEEK_API_KEY to be set)
claude-deepseek

# Pass arguments through to claude
claude-pro --resume
claude-deepseek --dangerously-skip-permissions
```

### Command Prompt

```cmd
:: Use Claude Pro
claude-pro

:: Use DeepSeek (requires DEEPSEEK_API_KEY env var)
set DEEPSEEK_API_KEY=<DeepSeek API>
claude-deepseek
```

---

## DeepSeek Model Mapping

When using `claude-deepseek`, all Claude Code model slots are mapped as follows:

| Claude Code slot | DeepSeek model |
|---|---|
| Default / Opus | `deepseek-v4-pro` (with 1M context) |
| Sonnet | `deepseek-v4-pro` |
| Haiku | `deepseek-v4-flash` |
| Subagent | `deepseek-v4-pro` |

Effort level is set to `max` and timeout to 600 seconds (10 minutes) to accommodate longer DeepSeek responses.

---

## Requirements

- [Claude Code CLI](https://claude.ai/code) installed and on your `PATH`
- A [DeepSeek API key](https://platform.deepseek.com/) (only needed for `claude-deepseek`)
- Windows with PowerShell 5.x or PowerShell 7+
