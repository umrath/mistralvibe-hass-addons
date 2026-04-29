#!/usr/bin/with-contenv bashio
# ==============================================================================
# Initialise Mistral Vibe inside the add-on container.
#
# Runs once at container start (before services). Populates VIBE_HOME=/data/vibe
# with a config.toml + .env tailored to the user's add-on options and wires
# hass-mcp up to the Supervisor API.
# ==============================================================================
set -e

VIBE_HOME="/data/vibe"
ENV_FILE="${VIBE_HOME}/.env"
CONFIG_FILE="${VIBE_HOME}/config.toml"
TRUST_FILE="${VIBE_HOME}/trusted_folders.toml"
LOG_DIR="${VIBE_HOME}/logs/session"

mkdir -p "${VIBE_HOME}/agents" "${VIBE_HOME}/prompts" "${LOG_DIR}"

# ---------- read add-on options ----------------------------------------------
MISTRAL_API_KEY="$(bashio::config 'mistral_api_key')"
ACTIVE_MODEL="$(bashio::config 'active_model')"
DEFAULT_AGENT="$(bashio::config 'default_agent')"
AUTO_APPROVE="$(bashio::config 'auto_approve')"
AUTO_UPDATE_CLI="$(bashio::config 'auto_update_cli')"
ENABLE_TELEMETRY="$(bashio::config 'enable_telemetry')"

if [ -z "${MISTRAL_API_KEY}" ] || [ "${MISTRAL_API_KEY}" = "null" ]; then
    bashio::log.fatal "No 'mistral_api_key' configured."
    bashio::log.fatal "Open https://console.mistral.ai/ to obtain a key,"
    bashio::log.fatal "then add it under the add-on Configuration tab."
    exit 1
fi

# ---------- .env (API keys + HA bridge) --------------------------------------
cat > "${ENV_FILE}" <<EOF
MISTRAL_API_KEY=${MISTRAL_API_KEY}
HA_URL=http://supervisor/core
HA_TOKEN=${SUPERVISOR_TOKEN}
EOF
chmod 600 "${ENV_FILE}"

# ---------- config.toml (created on first start, preserved afterwards) -------
bashio::log.info "Writing Vibe config from template to ${CONFIG_FILE}"
cp /usr/share/vibe-defaults/config.toml.tpl "${CONFIG_FILE}"

# Always overwrite the managed-by-addon settings so HA options stay authoritative
python3 - "$CONFIG_FILE" "$ACTIVE_MODEL" "$AUTO_UPDATE_CLI" "$ENABLE_TELEMETRY" <<'PY'
import sys, re, pathlib
path, model, auto_update, telemetry = sys.argv[1:]
text = pathlib.Path(path).read_text()

def upsert(key, value):
    global text
    pattern = re.compile(rf"^{key}\s*=.*$", re.MULTILINE)
    if pattern.search(text):
        text = pattern.sub(f"{key} = {value}", text)
    else:
        text += f"\n{key} = {value}\n"

upsert("active_model", f'"{model}"')
upsert("enable_update_checks", "true" if auto_update == "true" else "false")
upsert("enable_telemetry", "true" if telemetry == "true" else "false")

pathlib.Path(path).write_text(text)
PY

# ---------- mark /config and /share as trusted directories -------------------
# Vibe asks for confirmation when entering an unknown folder. Pre-trust the
# Home Assistant config + share dirs so the user isn't prompted on every start.
cat > "${TRUST_FILE}" <<'EOF'
trusted_folders = [
  "/config",
  "/share",
  "/addon_config",
  "/data/vibe",
]
EOF

# ---------- read-only ("plan") agent if the user asked for it ----------------
if [ "${DEFAULT_AGENT}" = "plan" ]; then
    bashio::log.info "Default agent: PLAN (read-only mode)"
fi

# ---------- auto-approve helper ----------------------------------------------
# We don't switch the global default. Instead we let the launcher add
# --auto-approve when the user opted in via add-on options.
echo "${AUTO_APPROVE}" > "${VIBE_HOME}/.auto_approve"
echo "${DEFAULT_AGENT}" > "${VIBE_HOME}/.default_agent"

bashio::log.info "Mistral Vibe initialised in ${VIBE_HOME}"
bashio::log.info "Active model: ${ACTIVE_MODEL}, agent: ${DEFAULT_AGENT}, auto-approve: ${AUTO_APPROVE}"
