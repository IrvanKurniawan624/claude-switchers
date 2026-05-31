# Claude Code Model Switchers

Switch [Claude Code](https://claude.ai/code) between **Claude Pro** and any **Anthropic-API-compatible provider** — DeepSeek, Kimi, GLM, Qwen, MiniMax, OpenRouter, or your own custom endpoint — without touching any config files.

---

## Commands

| Command | What it does |
|---|---|
| `claude-pro` | Launch Claude Code with your Claude Pro subscription |
| `claude-deepseek` | Launch with DeepSeek |
| `claude-kimi` | Launch with Kimi K2 (Moonshot) |
| `claude-glm` | Launch with GLM (Z.ai) |
| `claude-<id>` | Launch with any enabled provider |
| `claude-switch` | Arrow-key picker — choose a provider interactively |
| `claude-switch <id>` | Launch a specific provider directly, e.g. `claude-switch kimi` |
| `claude-status` | Show which provider is active in the current session |
| `claude-config` | Open the config menu — manage providers, keys, custom endpoints |

All launch commands pass extra arguments through to `claude`:

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

| ID | Provider | Endpoint | Default |
|---|---|---|---|
| `pro` | Claude Pro (subscription) | *(Anthropic default)* | enabled |
| `deepseek` | DeepSeek | `api.deepseek.com/anthropic` | enabled |
| `kimi` | Kimi K2 (Moonshot) | `api.moonshot.ai/anthropic` | disabled |
| `glm` | GLM (Z.ai) | `api.z.ai/api/anthropic` | disabled |
| `qwen` | Qwen (Alibaba) | `dashscope-intl.aliyuncs.com/apps/anthropic` | disabled |
| `minimax` | MiniMax M2 | `api.minimax.io/anthropic` | disabled |
| `openrouter` | OpenRouter | `openrouter.ai/api` | disabled |

Enable any provider and set its API key via `claude-config`.

> If you have an older `config.json` with stale endpoints, they are updated automatically the next time any command loads the config — your keys and custom providers are not touched.

---

## Files

| File | Description |
|---|---|
| `config.example.json` | Provider presets template — committed to git |
| `config.json` | Your live config with API keys — **never committed** |
| `ClaudeSwitch.Core.ps1` | Shared config/launch/menu functions |
| `ClaudeModelSwitchers.ps1` | Loaded by your PowerShell profile; registers all commands |
| `claude-launch.ps1` | Non-interactive launcher used by per-provider CMD shims |
| `claude-switch.ps1` | Interactive picker script used by `claude-switch.cmd` |
| `claude-config.ps1` | Interactive config TUI |
| `claude-config.cmd` / `claude-switch.cmd` | CMD entry shims |
| `launchers/claude-<id>.cmd` | Per-provider CMD shims (generated, not committed) |
| `install-switchers.ps1` | One-time installer |
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

If you move the folder later, re-run the installer from the new location — it updates both profiles and **removes the old PATH entries** automatically.

> **Note:** The installer only patches profiles that already exist. If you have no profile, it will tell you the command to create one.

### Step 3 — Set your API keys

```powershell
claude-config
```

Use the arrow keys to select a provider, then choose **Set API key**. The key is validated against the provider's endpoint before saving. Press **Esc** or select **Save & quit** when done.

### Step 4 — Open a new terminal

Profile changes take effect in any new PowerShell or Command Prompt window.

---

## Managing providers

### Config menu

```powershell
claude-config
```

```
==========================================
   Claude Code Provider Config
==========================================

  > Claude Pro            enabled    (subscription)
    DeepSeek              enabled    key: set
    Kimi (Moonshot K2)    disabled   key: NOT SET
    GLM (Z.ai)            disabled   key: NOT SET
    Qwen (Alibaba)        disabled   key: NOT SET
    MiniMax (M2)          disabled   key: NOT SET
    OpenRouter            disabled   key: NOT SET
    ------------------------------------------
    Add custom provider
    Regenerate CMD commands
    Uninstall
    Save & quit

  [up/down] move   [enter] select   [esc] back
```

Use **arrow keys** to navigate, **Enter** to select. Selecting a provider opens its submenu where you can toggle it on/off, set or clear its API key, edit the base URL, or edit the model/env mapping.

> **Disabled providers cannot be launched** — calling `claude-kimi` while Kimi is disabled shows a clear message instead of silently failing. Disabling a provider also immediately removes its `claude-<id>` command from your PowerShell session.

### Provider submenu

```
==========================================
    Provider: Kimi (Moonshot K2)
==========================================

  > Toggle  (currently: DISABLED)
    ------------------------------------------
    Set API key  (not set)
    Clear API key
    Edit base URL  (https://api.moonshot.ai/anthropic)
    Edit model / env overrides
    ------------------------------------------
    Delete this provider
    ------------------------------------------
    Back
```

### Add a custom provider

Select **Add custom provider** in the config menu. You'll be prompted for:
- Short ID (becomes the `claude-<id>` command, e.g. `myprovider` → `claude-myprovider`)
- Display name
- Base URL (any Anthropic-compatible endpoint)
- API key
- Default model name

The new command is available immediately in the current PowerShell session and in new CMD windows after saving.

### API key validation

After setting a key you'll be asked whether to test it. The test hits the provider's `/v1/models` endpoint and reports:
- `OK` — key is valid
- `invalid key (401)` — wrong key
- `reachable, key untested` — server responded but endpoint doesn't support `/models`; key is likely fine
- `could not connect` — wrong base URL or no internet

The key is saved regardless so you can correct it later.

### Editing model / env overrides

Inside a provider's submenu, **Edit model / env overrides** opens a line editor:

```
  Enter KEY=VALUE to set, KEY= to clear an override.
  Type 'back' to finish.
```

- `ANTHROPIC_MODEL=my-model-name` — set a value
- `ANTHROPIC_MODEL=` — clear/remove that override
- blank Enter — does nothing (so you can't accidentally exit)
- `back` — save and return to the provider submenu

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

```powershell
claude-config
```

Navigate to **Uninstall** and confirm. This removes the profile patches, user PATH entries, `launchers\`, `config.json`, and `.env`. The repo folder itself is not deleted.

---

## Requirements

- [Claude Code CLI](https://claude.ai/code) installed and on your `PATH`
- Windows with PowerShell 5.x or PowerShell 7+
- API keys for whichever third-party providers you enable
