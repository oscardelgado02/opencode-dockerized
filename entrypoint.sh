#!/bin/bash
set -e

CONFIG_DIR="/home/coder/.config/opencode"
CONFIG_FILE="$CONFIG_DIR/opencode.json"
AUTH_DIR="/home/coder/.local/share/opencode"

mkdir -p "$CONFIG_DIR" "$AUTH_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  PERMISSION_BLOCK=$(cat <<EOF
  "permission": {
    "read": "${OPENCODE_PERMISSION_READ:-ask}",
    "edit": "${OPENCODE_PERMISSION_EDIT:-ask}",
    "bash": "${OPENCODE_PERMISSION_BASH:-ask}",
    "glob": "${OPENCODE_PERMISSION_GLOB:-ask}",
    "grep": "${OPENCODE_PERMISSION_GREP:-ask}",
    "list": "${OPENCODE_PERMISSION_LIST:-ask}",
    "webfetch": "${OPENCODE_PERMISSION_WEBFETCH:-ask}",
    "websearch": "${OPENCODE_PERMISSION_WEBSEARCH:-ask}",
    "task": "${OPENCODE_PERMISSION_TASK:-ask}",
    "external_directory": "${OPENCODE_PERMISSION_EXTERNAL_DIRECTORY:-ask}"
  }
EOF
)

  if [ -n "$OPENCODE_MODEL" ]; then
    if [ -n "$OPENCODE_LOCAL_MODEL_URL" ]; then
      cat > "$CONFIG_FILE" <<DMREOF
{
  "\$schema": "https://opencode.ai/config.json",
$PERMISSION_BLOCK,
  "provider": {
    "dmr": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Docker Model Runner",
      "options": {
        "baseURL": "${OPENCODE_LOCAL_MODEL_URL}/engines/v1"
      },
      "models": {
        "$OPENCODE_MODEL": {
          "name": "$OPENCODE_MODEL"
        }
      }
    }
  },
  "model": "dmr/$OPENCODE_MODEL"
}
DMREOF
    else
      cat > "$CONFIG_FILE" <<MODELEOF
{
  "\$schema": "https://opencode.ai/config.json",
$PERMISSION_BLOCK,
  "model": "$OPENCODE_MODEL"
}
MODELEOF
    fi
  else
    cat > "$CONFIG_FILE" <<BASEEOF
{
  "\$schema": "https://opencode.ai/config.json",
$PERMISSION_BLOCK
}
BASEEOF
  fi
fi

exec "$@"
