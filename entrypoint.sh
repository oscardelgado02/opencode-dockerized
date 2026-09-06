#!/bin/bash
set -e

HOME_DIR="${HOME:-/home/coder}"
CONFIG_DIR="$HOME_DIR/.config/opencode"
CONFIG_FILE="$CONFIG_DIR/opencode.json"
AUTH_DIR="$HOME_DIR/.local/share/opencode"

mkdir -p "$CONFIG_DIR" "$AUTH_DIR"

# Sync skills shipped in the image into the (persistent) config volume.
# Re-copied on every start so image updates always win over volume copies.
SKILLS_SRC="${OPENCODE_SKILLS_SRC:-/usr/local/share/opencode-skills}"
SKILL_NAME="unity-cli"
if [ -d "$SKILLS_SRC/$SKILL_NAME" ]; then
  rm -rf "$CONFIG_DIR/skills/$SKILL_NAME"
  mkdir -p "$CONFIG_DIR/skills"
  cp -R "$SKILLS_SRC/$SKILL_NAME" "$CONFIG_DIR/skills/$SKILL_NAME"
  echo "[entrypoint] Installed $SKILL_NAME skill -> $CONFIG_DIR/skills/"
elif [ -d "$CONFIG_DIR/skills/$SKILL_NAME" ]; then
  rm -rf "$CONFIG_DIR/skills/$SKILL_NAME"
  echo "[entrypoint] Removed stale $SKILL_NAME skill (image built with WITH_UNITY=0)"
fi

PERMISSION_JSON=$(cat <<EOF
{
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

if [ ! -f "$CONFIG_FILE" ]; then
  jq -n --argjson perm "$PERMISSION_JSON" '{"$schema": "https://opencode.ai/config.json", "permission": $perm}' > "$CONFIG_FILE"
fi

if [ -n "$OPENCODE_LOCAL_MODEL_URL" ] && [ -n "$OPENCODE_MODEL" ]; then
  PROVIDER_JSON=$(jq -n --arg url "${OPENCODE_LOCAL_MODEL_URL}/engines/v1" --arg model "$OPENCODE_MODEL" \
    '{dmr: {npm: "@ai-sdk/openai-compatible", name: "Docker Model Runner", options: {baseURL: $url}, models: {($model): {name: $model}}}}')
  jq --argjson provider "$PROVIDER_JSON" --arg model "dmr/$OPENCODE_MODEL" \
    '.provider = (.provider // {}) * $provider | .model = $model' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
elif [ -n "$OPENCODE_MODEL" ]; then
  jq --arg model "$OPENCODE_MODEL" '.model = $model' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
fi

exec "$@"
