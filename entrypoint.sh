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
# Override with OPENCODE_BUNDLED_PLUGINS (a JSON array); set to [] for none.
BUNDLED_PLUGINS="${OPENCODE_BUNDLED_PLUGINS:-[\"@dietrichgebert/ponytail\", \"@tarquinen/opencode-dcp\"]}"

PERMISSION_RULES=$(jq -n '
  [ $ARGS.named | to_entries[]
    | select(.value != "")
    | {action: .key, resource: "*", effect: .value} ]' \
  --arg read "${OPENCODE_PERMISSION_READ:-}" \
  --arg edit "${OPENCODE_PERMISSION_EDIT:-}" \
  --arg shell "${OPENCODE_PERMISSION_SHELL:-}" \
  --arg glob "${OPENCODE_PERMISSION_GLOB:-}" \
  --arg grep "${OPENCODE_PERMISSION_GREP:-}" \
  --arg webfetch "${OPENCODE_PERMISSION_WEBFETCH:-}" \
  --arg websearch "${OPENCODE_PERMISSION_WEBSEARCH:-}" \
  --arg subagent "${OPENCODE_PERMISSION_SUBAGENT:-}" \
  --arg external_directory "${OPENCODE_PERMISSION_EXTERNAL_DIRECTORY:-}")

# Blanket rules first, OPENCODE_PERMISSION_RULES (a JSON array) appended last:
# v2 uses last matching rule wins, so exceptions override the blanket rules.
PERMISSIONS=$(jq -cn --argjson base "$PERMISSION_RULES" \
  --argjson extra "${OPENCODE_PERMISSION_RULES:-[]}" '$base + $extra')

if [ ! -f "$CONFIG_FILE" ]; then
  jq -n --argjson permissions "$PERMISSIONS" --argjson plugins "$BUNDLED_PLUGINS" \
    '{"$schema": "https://opencode.ai/config.json", "permissions": $permissions, "plugins": $plugins}' > "$CONFIG_FILE"
else
  # Idempotent: make sure configs created before this image still get the plugins.
  # Existing permission rules are left untouched so user exceptions survive;
  # v2 still normalizes configs created by the v1 image.
  jq --argjson plugins "$BUNDLED_PLUGINS" \
    '.plugins = ((.plugins // []) + $plugins | unique)' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" \
    && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
fi

if [ -d "$CAVEMAN_SRC/plugins" ]; then
  # v2 loads plugins from a directory (caveman's server.js); v1 imported the
  # directory's package.json main, so this entry works on both majors.
  jq --arg p './plugins/caveman' \
    '.plugins = ((.plugins // []) + [$p] | unique)' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" \
    && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
fi

if [ -n "$OPENCODE_LOCAL_MODEL_URL" ] && [ -n "$OPENCODE_MODEL" ]; then
  PROVIDER_JSON=$(jq -n --arg url "${OPENCODE_LOCAL_MODEL_URL}/engines/v1" --arg model "$OPENCODE_MODEL" \
    '{dmr: {package: "aisdk:@ai-sdk/openai-compatible", settings: {baseURL: $url}, models: {($model): {name: $model}}}}')
  jq --argjson provider "$PROVIDER_JSON" --arg model "dmr/$OPENCODE_MODEL" \
    '.providers = (.providers // {}) * $provider | .model = $model' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
elif [ -n "$OPENCODE_MODEL" ]; then
  jq --arg model "$OPENCODE_MODEL" '.model = $model' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
fi

exec "$@"
