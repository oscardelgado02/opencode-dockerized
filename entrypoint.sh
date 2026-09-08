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
mkdir -p "$CONFIG_DIR/skills"
if [ -d "$SKILLS_SRC" ]; then
  for SKILL_PATH in "$SKILLS_SRC"/*/; do
    SKILL_NAME=$(basename "$SKILL_PATH")
    rm -rf "$CONFIG_DIR/skills/$SKILL_NAME"
    cp -R "$SKILL_PATH" "$CONFIG_DIR/skills/$SKILL_NAME"
    echo "[entrypoint] Installed $SKILL_NAME skill -> $CONFIG_DIR/skills/"
  done
fi
if [ ! -d "$SKILLS_SRC/unity-cli" ] && [ -d "$CONFIG_DIR/skills/unity-cli" ]; then
  rm -rf "$CONFIG_DIR/skills/unity-cli"
  echo "[entrypoint] Removed stale unity-cli skill (image built with WITH_UNITY=0)"
fi

# Sync graphify (skill + uv-managed CLI) into the persistent config volume.
# Version-gated: only copies when the image ships a different graphify, so the
# large uv-tools/uv-python payload isn't re-copied on every start.
GRAPHIFY_SRC="/usr/local/share/opencode-graphify"
SRC_VER=$(cat "$GRAPHIFY_SRC/skills/graphify/.graphify_version" 2>/dev/null || true)
DST_VER=$(cat "$CONFIG_DIR/skills/graphify/.graphify_version" 2>/dev/null || true)
if [ -n "$SRC_VER" ] && [ "$SRC_VER" != "$DST_VER" ]; then
  for ITEM in skills/graphify bin uv-tools uv-python; do
    rm -rf "$CONFIG_DIR/$ITEM"
    cp -R "$GRAPHIFY_SRC/$ITEM" "$CONFIG_DIR/$ITEM"
  done
  echo "[entrypoint] Installed graphify $SRC_VER (skill + CLI)"
fi

# Sync caveman (https://github.com/JuliusBrussee/caveman) opencode plugin
# payload into the persistent config volume; image updates always win.
CAVEMAN_SRC="/usr/local/share/opencode-caveman"
if [ -d "$CAVEMAN_SRC/plugins" ]; then
  mkdir -p "$CONFIG_DIR/plugins" "$CONFIG_DIR/commands" "$CONFIG_DIR/agents"
  rm -rf "$CONFIG_DIR/plugins/caveman"
  cp -R "$CAVEMAN_SRC/plugins/caveman" "$CONFIG_DIR/plugins/caveman"
  cp -R "$CAVEMAN_SRC/commands/." "$CONFIG_DIR/commands/"
  cp -R "$CAVEMAN_SRC/agents/." "$CONFIG_DIR/agents/"
  cp -R "$CAVEMAN_SRC/skills/." "$CONFIG_DIR/skills/"
  cp "$CAVEMAN_SRC/.caveman-opencode-ownership.json" "$CONFIG_DIR/" 2>/dev/null || true
  # Always-on ruleset; append unless the fenced block is already present.
  if [ ! -f "$CONFIG_DIR/AGENTS.md" ]; then
    cp "$CAVEMAN_SRC/AGENTS.md" "$CONFIG_DIR/AGENTS.md"
  elif ! grep -q '<!-- caveman-begin -->' "$CONFIG_DIR/AGENTS.md"; then
    cat "$CAVEMAN_SRC/AGENTS.md" >> "$CONFIG_DIR/AGENTS.md"
  fi
  echo "[entrypoint] Installed caveman opencode plugin -> $CONFIG_DIR/plugins/"
fi

# Plugins bundled with the image. opencode auto-installs anything listed here.
BUNDLED_PLUGINS='["@dietrichgebert/ponytail", "@tarquinen/opencode-dcp"]'

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
  jq -n --argjson perm "$PERMISSION_JSON" --argjson plugins "$BUNDLED_PLUGINS" \
    '{"$schema": "https://opencode.ai/config.json", "permission": $perm, "plugin": $plugins}' > "$CONFIG_FILE"
else
  # Idempotent: make sure configs created before this image still get the plugins.
  jq --argjson plugins "$BUNDLED_PLUGINS" \
    '.plugin = ((.plugin // []) + $plugins | unique)' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" \
    && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
fi

if [ -d "$CAVEMAN_SRC/plugins" ]; then
  jq --arg p './plugins/caveman/plugin.js' \
    '.plugin = ((.plugin // []) + [$p] | unique)' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" \
    && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
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
