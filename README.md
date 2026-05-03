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
| `claude-pro.cmd` | Sets Claude Code to use your Claude Pro subscription and launches `claude` |
| `claude-deepseek.cmd` | Sets Claude Code to use the DeepSeek API and launches `claude` |
| `ClaudeModelSwitchers.ps1` | Loaded by your PowerShell profile on startup — pre-loads `.env` into the session |
| `install-switchers.ps1` | One-time installer: patches PowerShell profiles and adds folder to user `PATH` |
| `uninstall-switchers.ps1` | Removes profile patches, removes folder from user `PATH`, and deletes `.env` |
| `.env` | Your API key — **never committed**, lives only on your machine |
| `.env.example` | Template showing what goes in `.env` |

---

## Installation

### Step 1 — Clone the repo

```
git clone https://github.com/IrvanKurniawan624/claude-switchers.git
```

Place it anywhere on your system, for example:

```
C:\Users\YourName\claude-switchers
```

### Step 2 — Add your DeepSeek API key

Copy `.env.example` to `.env` in the same folder:

```powershell
Copy-Item ".env.example" ".env"
```

Then open `.env` and replace the placeholder with your real key:

```
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxx
```

Get your API key from [platform.deepseek.com](https://platform.deepseek.com/).

> `.env` is listed in `.gitignore` — it will **never** be committed or pushed to GitHub.

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

> **Note:** The installer only patches profile files that already exist. If you have no profile yet, it will tell you the command to create one and ask you to re-run the installer.

> **Upgrading from an earlier version?** Just re-run the installer — it will automatically clean up any profile files it previously created that are no longer needed.

### Step 4 — Open a new terminal

The profile changes take effect in any new PowerShell or Command Prompt window.

---

## Usage

### PowerShell

```powershell
# Use Claude Pro (subscription)
claude-pro

# Use DeepSeek — reads DEEPSEEK_API_KEY from .env automatically
claude-deepseek

# Pass arguments through to claude
claude-pro --resume
claude-deepseek --dangerously-skip-permissions
```

### Command Prompt

```cmd
:: Use Claude Pro
claude-pro

:: Use DeepSeek — reads DEEPSEEK_API_KEY from .env automatically
claude-deepseek
```

No need to manually set `DEEPSEEK_API_KEY` each session — both scripts load it from `.env` on the fly if it isn't already set in your environment.

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

## Uninstallation

To fully remove claude-switchers from your system, run:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\path\to\claude-switchers\uninstall-switchers.ps1"
```

The uninstaller does three things:
1. **Removes the switchers block** from both PowerShell profiles (`WindowsPowerShell\profile.ps1` and `PowerShell\profile.ps1`)
2. **Removes the folder from your user `PATH`** so the commands are no longer available in Command Prompt
3. **Deletes your `.env` file** so your API key is cleaned up

Open a new terminal after running it to confirm everything is gone. The repo folder itself is not deleted — remove it manually if you no longer need it.

---

## Requirements

- [Claude Code CLI](https://claude.ai/code) installed and on your `PATH`
- A [DeepSeek API key](https://platform.deepseek.com/) (only needed for `claude-deepseek`)
- Windows with PowerShell 5.x or PowerShell 7+
