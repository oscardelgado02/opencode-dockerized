#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="system"
ACTION="install"
PURGE=false

show_help() {
    cat <<EOF
Usage: install.sh [OPTIONS]

Install or uninstall the safe-code wrapper in one command.

  (no flags)        Install system-wide (/usr/local/share/safe-code, needs sudo)
  --user            Install for the current user only (~/.local/share/safe-code)
  --uninstall       Remove safe-code (script, files, shell config lines)
  --purge           With --uninstall: also remove the Docker image and volumes
  -h, --help        Show this help

Examples:
  ./install.sh                  # system-wide install
  ./install.sh --user           # user-only install
  ./install.sh --uninstall      # uninstall (keeps Docker image/volumes)
  ./install.sh --uninstall --purge  # uninstall + remove image and volumes
EOF
}

for arg in "$@"; do
  case "$arg" in
    --user) MODE="user" ;;
    --uninstall) ACTION="uninstall" ;;
    --purge) PURGE=true ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown option: $arg"; show_help; exit 1 ;;
  esac
done

if [ "$MODE" = "user" ]; then
  SAFE_CODE_HOME="$HOME/.local/share/safe-code"
  BIN_DIR="$HOME/.local/bin"
  SUDO=""
else
  SAFE_CODE_HOME="/usr/local/share/safe-code"
  BIN_DIR="/usr/local/bin"
  if [ "$(id -u)" != "0" ]; then SUDO="sudo"; fi
fi

FILES=(Dockerfile docker-compose.yml entrypoint.sh shims skills bridge safe-code
  .env.safe .env.auto .env.balanced .env.example .env LICENSE README.md)

if [ "$ACTION" = "uninstall" ]; then
  if [ "$PURGE" = true ] && command -v docker >/dev/null 2>&1 && [ -f "$SAFE_CODE_HOME/docker-compose.yml" ]; then
    echo "Removing Docker containers, volumes and the safe-opencode image..."
    docker compose -f "$SAFE_CODE_HOME/docker-compose.yml" down -v --remove-orphans 2>/dev/null || true
    docker rmi safe-opencode 2>/dev/null || true
  fi
  rm -f "$BIN_DIR/safe-code"
  rm -rf "$SAFE_CODE_HOME"
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ]; then
      sed -i.bak '/export SAFE_CODE_HOME=/d' "$rc"
    fi
  done
  echo "safe-code uninstalled (config/auth volumes kept; use --purge to remove Docker data)."
  echo "Run 'source ~/.bashrc' to refresh your shell."
  exit 0
fi

# ---- install ----
for f in "${FILES[@]}"; do
  if [ ! -e "$REPO_DIR/$f" ]; then
    echo "Error: missing required file: $REPO_DIR/$f"
    echo "Run this from a full clone of the repository."
    exit 1
  fi
done

$SUDO mkdir -p "$SAFE_CODE_HOME"
$SUDO cp -r "${FILES[@]}" "$SAFE_CODE_HOME/"
$SUDO mkdir -p "$BIN_DIR"
$SUDO cp safe-code "$BIN_DIR/safe-code"
$SUDO chmod +x "$BIN_DIR/safe-code"

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ -f "$rc" ] && ! grep -q "export SAFE_CODE_HOME=$SAFE_CODE_HOME" "$rc"; then
    echo "export SAFE_CODE_HOME=$SAFE_CODE_HOME" >> "$rc"
    echo "Added SAFE_CODE_HOME to $rc"
  fi
done

echo "safe-code installed to $SAFE_CODE_HOME (launcher: $BIN_DIR/safe-code)"
echo "Next: cp .env.safe .env, edit your API keys, then run: safe-code"
[ "$MODE" != "user" ] || echo "Add ~/.local/bin to PATH if it isn't already: export PATH=\"\$HOME/.local/bin:\$PATH\""
