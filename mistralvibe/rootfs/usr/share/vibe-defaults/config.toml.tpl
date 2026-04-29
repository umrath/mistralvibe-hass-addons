# ==============================================================================
# Mistral Vibe – Home Assistant Add-on default configuration.
# Generated on first container start. Edit at /data/vibe/config.toml.
# Note: the keys "active_model", "enable_update_checks" and "enable_telemetry"
# are re-applied from the add-on options on every restart.
# ==============================================================================

active_model = "devstral-2"
vim_keybindings = false
textual_theme = "textual-dark"
auto_compact_threshold = 200000
context_warnings = true
system_prompt_id = "cli"
include_commit_signature = true
include_model_info = true
include_project_context = true
enable_update_checks = true
enable_telemetry = false
api_timeout = 720.0
disable_welcome_banner_animation = true

# ---------- Providers --------------------------------------------------------
[[providers]]
name = "mistral"
api_base = "https://api.mistral.ai/v1"
api_key_env_var = "MISTRAL_API_KEY"
backend = "mistral"

# ---------- Models -----------------------------------------------------------
[[models]]
name = "devstral-2"
provider = "mistral"
alias = "devstral-2"
input_price = 0.4
output_price = 2.0

[[models]]
name = "devstral-small-2"
provider = "mistral"
alias = "devstral-small-2"
input_price = 0.1
output_price = 0.3

[[models]]
name = "magistral-medium-latest"
provider = "mistral"
alias = "magistral-medium"
temperature = 0.2

[[models]]
name = "mistral-medium-latest"
provider = "mistral"
alias = "mistral-medium-latest"

[[models]]
name = "codestral-latest"
provider = "mistral"
alias = "codestral-latest"

# ---------- Project context --------------------------------------------------
[project_context]
max_chars = 60000
default_commit_count = 5

# ---------- Session logging --------------------------------------------------
[session_logging]
save_dir = "/data/vibe/logs/session"
enabled = true

# ---------- Tool permissions -------------------------------------------------
[tools]
tool_paths = []
enabled_tools = []
disabled_tools = []

# ---------- MCP servers ------------------------------------------------------
# hass-mcp gives Vibe direct access to the Home Assistant API. It runs as a
# stdio child process; HA_URL and HA_TOKEN are injected via env vars by the
# add-on init script (.env in VIBE_HOME).
[[mcp_servers]]
name = "hass"
transport = "stdio"
command = "hass-mcp"
args = []
startup_timeout_sec = 30
