# Mistral Vibe — Home Assistant App

Run **Mistral Vibe CLI** (Mistral AI's open-source agentic coding agent powered
by Devstral 2) directly inside Home Assistant. Talk to your smart home in
natural language through a browser terminal that has full access to entities,
services, automations and YAML configs via a custom MCP server.

## What you get

- A web terminal in the HA sidebar (no SSH, no separate IDE)
- Multi-file editing across `/config`, `/share` and `/media`
- Live entity & service inspection via the Supervisor API
- Persistent sessions, command history and conversation logs in `/data/vibe`
- Open-source, Apache 2.0 licensed CLI on top of open-weight Devstral models
- A read-only "plan" mode for exploration without any writes

## API Key & Kosten

Mistral Vibe unterstützt zwei Abrechnungsmodelle:

### Le Chat Pro (empfohlen für intensive Nutzung)

Le Chat Pro beinhaltet ein monatliches Vibe-Budget das auch mit der CLI – und damit mit dieser App – genutzt werden kann.

1. Abo abschließen unter https://chat.mistral.ai
2. API-Key erstellen unter **Studio → Codestral → API keys**
3. Diesen Key als `mistral_api_key` in der App-Konfiguration eintragen

Wenn das monatliche Budget aufgebraucht ist, wird Vibe standardmäßig bis zur nächsten Abrechnungsperiode deaktiviert. Im Mistral Admin Panel kann optional Pay-as-you-go aktiviert werden, damit es nahtlos weiterläuft.

> **Hinweis:** Le Chat Pro über Partner-Angebote (Google, Apple, Free Mobile, Orange) unterstützt Pay-as-you-go nach Budgetausschöpfung nicht.

### Pay-as-you-go (Experiment / Scale Plan)

Für gelegentliche Nutzung oder zum Ausprobieren:

1. Account erstellen unter https://console.mistral.ai
2. API-Key erstellen unter **Studio → Organization → API keys**
3. Key als `mistral_api_key` eintragen

Abrechnung per Token. Aktuelle Preise: Devstral Small 2 ab $0.10/1M Input-Token, Devstral 2 ab $0.40/1M Input-Token.

## First-time setup

1. Erstelle einen Mistral API-Key (siehe **API Key & Kosten** oben).
2. Open this app, switch to the **Configuration** tab and paste your key
   into `mistral_api_key`. Save.
3. Start the app. Open the **Web UI** (or the sidebar entry).
4. The terminal opens directly in `/config` with Vibe ready to go. Try:
   - `List all my automations`
   - `Why did motion_sensor_hallway not trigger last night?`
   - `Create an automation to turn off all lights when nobody is home`

No long-lived HA token is required — the app uses the Supervisor token
internally to authenticate `hass-mcp` against Home Assistant Core.

## Configuration options

| Option | Default | Description |
| --- | --- | --- |
| `mistral_api_key` | *(required)* | Your Mistral API key. Stored in `/data/vibe/.env`, never sent anywhere except `api.mistral.ai`. |
| `active_model` | `devstral-2` | One of `devstral-2`, `devstral-small-2`, `magistral-medium`, `mistral-medium-latest`, `codestral-latest`. Switch on the fly inside Vibe with `/config`. |
| `default_agent` | `default` | `default` asks before every tool call. `plan` is a fully read-only agent — Vibe can look around but cannot edit, run shells or call services. |
| `auto_approve` | `false` | When `true`, Vibe skips the confirmation prompt before running tools. **Convenient but dangerous.** Leave off unless you really know what you're doing. |
| `auto_update_cli` | `true` | Lets Vibe self-update on launch when a newer release is on PyPI. Disable to pin the version that ships with the app. |
| `enable_telemetry` | `false` | Forwarded to Vibe as the `enable_telemetry` config flag. Off by default. |
| `log_level` | `info` | Controls the verbosity of the underlying `ttyd` server (`trace`, `debug`, `info`, `notice`, `warning`, `error`, `fatal`). |

Every option above maps 1:1 to a key the init script writes into
`/data/vibe/config.toml` or `/data/vibe/.env` — so you can also edit them
directly in a Vibe session if you want full control.

## File-system layout inside the app

| Path | Purpose |
| --- | --- |
| `/config` | Your Home Assistant configuration (mounted RW). Vibe's working dir. |
| `/share` | Shared data (mounted RW). |
| `/media` | Media folder (mounted RW). |
| `/ssl` | TLS certificates (mounted RO). |
| `/data/vibe` | Vibe state: `config.toml`, `.env`, `agents/`, `prompts/`, `logs/session/`, command history. Persists across restarts and updates. |

## Architecture

```
 ┌───────────────────┐ HTTP    ┌────────────────────────┐
 │  HA Frontend      │────────▶│  Supervisor Ingress    │
 │  (sidebar panel)  │◀────────│  (/api/hassio_ingress) │
 └───────────────────┘         └──────────┬─────────────┘
                                          │
                                          ▼
                              ┌──────────────────────────┐
                              │  ttyd  :7681             │
                              │  └─ bash                 │
                              │     └─ vibe-launcher     │
                              │        └─ mistral-vibe   │
                              └──────────┬───────────────┘
                                         │ stdio
                                         ▼
                              ┌──────────────────────────┐
                              │  custom MCP server       │  ──REST──▶  HA Core
                              │  (server.py + fastmcp)   │   /api/states
                              └──────────────────────────┘   /api/services
```

`vibe-launcher` is the entry-point that loads the API key from `.env`,
applies the `auto_approve` / `default_agent` flags from app options and
execs the CLI. The custom MCP server (`/usr/share/ha-mcp/server.py`) is started on demand by Vibe as a stdio child process. It receives `HA_URL` and `HA_TOKEN` via `[mcp_servers.env]` in `config.toml`.

## Switching models on the fly

Inside a Vibe session, type `/config`. You'll see the list of models defined
in `/data/vibe/config.toml` — pick one and Vibe switches without restarting.

You can also add custom providers (Ollama, vLLM, on-prem Mistral) by editing
the `[[providers]]` and `[[models]]` blocks in that file. Local inference is
fully supported.

## Security notes

- **Mistral API key** – gespeichert in `/data/vibe/.env` (chmod 600, nur root lesbar).
- **HA Supervisor Token** – steht in `/data/vibe/config.toml` unter `[mcp_servers.env]` als Klartext. Das ist ein bewusster Kompromiss: Vibe vererbt die Shell-Umgebung nicht an MCP-Kindprozesse, daher muss der Token explizit übergeben werden. `/data/vibe/config.toml` ist nur innerhalb des App-Containers zugänglich.
- **`hassio_role: manager`** – die App hat denselben Supervisor-Zugriff wie der offizielle Studio Code Server. Das ist nötig damit der MCP-Server Entities, Services und Automationen verwalten kann.
- **AppArmor** – standardmäßig aktiv. Das Profil erlaubt Lese-/Schreibzugriff auf `/config`, `/share`, `/data` und verwehrt alles andere.
- **`ha_call_service`** – der MCP-Server kann jeden HA-Service aufrufen, inkl. destruktiver wie `homeassistant.stop`. Für reine Inspektion ohne Schreibzugriff `default_agent: plan` verwenden.
- **`ha_restart`** – kann HA ohne Bestätigung neustarten wenn `auto_approve: true` gesetzt ist. Standardmäßig ist `auto_approve: false`.
- **`auto_approve: false`** – Standardwert. Vibe fragt vor jedem Tool-Call nach Bestätigung. Nur aktivieren wenn du weißt was du tust.


- The Mistral API key sits in `/data/vibe/.env` (mode `600`). Only this app
  can read it.
- The `SUPERVISOR_TOKEN` is the standard HA add-on token. The `hassio_role`
  is set to `manager`, the same level used by the official Studio Code Server
  add-on, so Vibe can manage entities, services, automations, snapshots, etc.
- AppArmor is **enabled by default**. The profile in `apparmor.txt` allows
  what the CLI needs (read/write under `/config`, `/share`, `/data` …) and
  denies the rest.
- For exploration without any side effects, set `default_agent: plan`.

## Differences vs. the Claude Code add-on

| Aspect | `claudecode` (robsonfelix) | `mistralvibe` (this) |
| --- | --- | --- |
| Engine | Claude Code (Anthropic, closed) | Mistral Vibe CLI (Apache 2.0, open) |
| Default model | Claude Sonnet | Devstral 2 (123B, open weights) |
| Auth | Anthropic OAuth (long URL flow) | Mistral API key in app options |
| Local inference | No | Yes (via Ollama / vLLM / on-prem) |
| HA bridge | hass-mcp via stdio | custom FastMCP server via stdio |
| Web UI | ttyd terminal in ingress | ttyd terminal in ingress |
| State dir | `/data/claude` | `/data/vibe` |

The two apps can be installed side-by-side — they use different slugs and
different state directories.

## Troubleshooting

- **"No mistral_api_key configured" on start** — open the app's
  Configuration tab, paste a key, save, then restart.
- **Terminal opens but `vibe` says it can't reach `api.mistral.ai`** — check
  the host's outbound network. The app does not require any port forwards;
  it only needs HTTPS egress.
- **`hass` MCP tools fail with 401** — the `SUPERVISOR_TOKEN` is rotated
  whenever the app restarts. A simple app restart fixes it.
- **Want to start clean** — stop the app, delete `/data/vibe`, start again.
  Your app options will rebuild the config; only command history and
  session logs are lost.

## Credits

- [Mistral AI](https://mistral.ai) — Devstral 2 and Mistral Vibe CLI
- [tsl0922/ttyd](https://github.com/tsl0922/ttyd) — browser terminal
- [robsonfelix/robsonfelix-hass-addons](https://github.com/robsonfelix/robsonfelix-hass-addons) — the Claude Code add-on this is structurally based on
