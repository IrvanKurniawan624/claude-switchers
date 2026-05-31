# Claude Code Model Switchers

Switch [Claude Code](https://claude.ai/code) between **Claude Pro** and any **Anthropic-API-compatible provider** — DeepSeek, Kimi, GLM, Qwen, MiniMax, OpenRouter, or your own custom endpoint — without touching any config files.

---

## Quick start

```powershell
claude-pro           # Claude Pro subscription (default)
claude-deepseek      # DeepSeek API
claude-kimi          # Kimi K2 (Moonshot)
claude-glm           # GLM (Z.ai)
claude-switch        # interactive picker — choose from all enabled providers
claude-config        # manage providers, API keys, add custom endpoints
```

All commands pass extra arguments straight through to `claude`:

```powershell
claude-deepseek --resume
claude-kimi --dangerously-skip-permissions
claude-switch pro --version
```

---

## How it works

Claude Code reads model identity and API routing from environment variables. This tool sets (or clears) those vars in the current process before launching `claude` — changes are **session-scoped** and never touch your global config.

| Variable | Purpose |
|---|---|
| `ANTHROPIC_BASE_URL` | Routes the API to an alternative provider endpoint |
| `ANTHROPIC_AUTH_TOKEN` | API key for the provider |
| `ANTHROPIC_MODEL` | Default model sent to the endpoint |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Model used for Opus-tier tasks |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Model used for Sonnet-tier tasks |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Model used for Haiku-tier tasks |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Model used for sub-agent tasks |
| `CLAUDE_CODE_EFFORT_LEVEL` | Effort level (`max` for most third-party providers) |
| `API_TIMEOUT_MS` | Timeout in milliseconds |

`claude-pro` clears all of these so Claude Code falls back to your subscription defaults.

---

## Built-in providers

| ID | Provider | Endpoint |
|---|---|---|
| `pro` | Claude Pro (subscription) | *(Anthropic default)* |
| `deepseek` | DeepSeek | `api.deepseek.com/anthropic` |
| `kimi` | Kimi K2 (Moonshot) | `api.moonshot.ai/anthropic` |
| `glm` | GLM (Z.ai) | `api.z.ai/api/anthropic` |
| `qwen` | Qwen (Alibaba) | `dashscope.aliyuncs.com/compatible-mode` |
| `minimax` | MiniMax M2 | `api.minimax.chat/v1` |
| `openrouter` | OpenRouter | `openrouter.ai/api/v1` |

`pro` and `deepseek` are enabled by default. All others are disabled — enable them and add your API key via `claude-config`.

---

## Files

| File | Description |
|---|---|
| `config.example.json` | Provider presets template — committed to git |
| `config.json` | Your live config with API keys — **never committed** |
| `ClaudeSwitch.Core.ps1` | Shared config/launch functions |
| `ClaudeModelSwitchers.ps1` | Loaded by your PowerShell profile; registers all commands |
| `claude-launch.ps1` | Non-interactive entry point used by CMD shims |
| `claude-config.ps1` | Interactive config TUI |
| `claude-config.cmd` / `claude-switch.cmd` | CMD entry shims |
| `launchers/claude-<id>.cmd` | Per-provider CMD shims (generated, not committed) |
| `install-switchers.ps1` | One-time installer |
| `uninstall-switchers.ps1` | Removes all installation artifacts |
| `.env` | Legacy API key file — still loaded for back-compat, never committed |
| `.env.example` | Template for the legacy `.env` file |

---

## Installation

### Step 1 — Clone the repo

```powershell
git clone https://github.com/IrvanKurniawan624/claude-switchers.git
```

Place it anywhere on your system.

### Step 2 — Run the installer

```powershell
powershell -ExecutionPolicy Bypass -File "C:\path\to\claude-switchers\install-switchers.ps1"
```

The installer:
1. **Patches your PowerShell profiles** — dot-sources `ClaudeModelSwitchers.ps1` so all commands are available in every new session
2. **Adds the folder (and `launchers\`) to user PATH** — so commands work from Command Prompt too
3. **Creates `config.json`** from the example template
4. **Migrates your DeepSeek key** from `.env` if you have one
5. **Generates per-provider CMD shims** in `launchers\`

If you move the folder later, re-run the installer from the new location — it updates the path in both profiles automatically.

> **Note:** The installer only patches profiles that already exist. If you have no profile, it will tell you the command to create one.

### Step 3 — Set your API keys

```powershell
claude-config
```

Select a provider by number → `k` to set API key → `q` to save and quit.

### Step 4 — Open a new terminal

Profile changes take effect in any new PowerShell or Command Prompt window.

---

## Managing providers

### Interactive menu

```powershell
claude-config
```

```
╔══════════════════════════════════════════╗
║     Claude Code Provider Config          ║
╚══════════════════════════════════════════╝

 #   Provider              Status      Key
 --- -------------------- ---------- ----------
 1   Claude Pro            enabled    (subscription)
 2   DeepSeek              enabled    set
 3   Kimi (Moonshot K2)    disabled   NOT SET
 4   GLM (Z.ai)            disabled   NOT SET
 5   Qwen (Alibaba)        disabled   NOT SET
 6   MiniMax (M2)          disabled   NOT SET
 7   OpenRouter            disabled   NOT SET

  [number]  manage provider
  a         add custom provider
  r         regenerate CMD launch commands
  u         uninstall claude-switchers
  q         save and quit
```

Per-provider submenu: **toggle on/off**, **set/clear API key**, **edit base URL**, **edit model mapping**, **delete**.

### Add a custom provider

In `claude-config` → `a` — you'll be prompted for:
- Short ID (becomes the `claude-<id>` command)
- Display name
- Base URL (Anthropic-compatible endpoint)
- API key
- Default model name

The command is available immediately in the current PowerShell session and in new CMD windows after saving.

---

## Upgrading from v0.1.0

Re-run the installer from the repo folder:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\path\to\claude-switchers\install-switchers.ps1"
```

It will:
- Migrate your `DEEPSEEK_API_KEY` from `.env` into `config.json` automatically
- Generate the new per-provider CMD shims
- Update both PowerShell profiles

The `claude-pro` and `claude-deepseek` commands continue to work exactly as before.

---

## Uninstallation

### Option A — via the config menu (recommended)

```powershell
claude-config
```

Then select `u` → type `uninstall` to confirm.

### Option B — via the uninstall script

```powershell
powershell -ExecutionPolicy Bypass -File "C:\path\to\claude-switchers\uninstall-switchers.ps1"
```

Both remove the profile patches, user PATH entries, `launchers\`, `config.json`, and `.env`. The repo folder itself is not deleted.

---

## Requirements

- [Claude Code CLI](https://claude.ai/code) installed and on your `PATH`
- Windows with PowerShell 5.x or PowerShell 7+
- API keys for whichever third-party providers you enable
