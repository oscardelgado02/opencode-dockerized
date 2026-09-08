# Uninstallation

## 1. Remove safe-code

One command — from the repo clone, `$SAFE_CODE_HOME`, or via the launcher:

```bash
safe-code --uninstall
# or: ./install.sh --uninstall   (from the repo or $SAFE_CODE_HOME)
```

This removes the `safe-code` launcher, `$SAFE_CODE_HOME` (with all project files), and the `SAFE_CODE_HOME` line from your shell config. Docker containers, the image, and volumes are kept.

To also delete Docker data (containers, config/auth volumes, image):

```bash
./install.sh --uninstall --purge
```

## 2. Stop and remove containers

```bash
docker compose down
```

## 3. Remove Docker images

```bash
docker rmi safe-opencode
```

## 4. Remove volumes

This deletes persisted config, credentials (including API keys), and cached data:

```bash
docker volume rm opencode-config opencode-auth opencode-cache
docker volume rm safe-opencode_opencode-config safe-opencode_opencode-auth safe-opencode_opencode-cache
```

Or remove all at once via compose:

```bash
docker compose down -v
```

## 5. Remove bundled plugins (optional)

Ponytail and DCP live in the `plugin` array of `~/.config/opencode/opencode.json` in the config volume; graphify also installs a skill and the `graphify` CLI into the same volume. Caveman adds its own entry to the same `plugin` array plus `plugins/caveman/`, `skills/caveman*`, `skills/cavecrew`, `commands/caveman*`, `agents/cavecrew-*`, and a fenced block in `AGENTS.md`. Removing them individually:

```bash
# Inside the container (or any editor on the volume): delete the plugin entries
# you don't want, e.g. everything except "@custom/...":
jq '.plugin = [.plugin[] | select(. != "@dietrichgebert/ponytail" and . != "@tarquinen/opencode-dcp" and . != "./plugins/caveman/plugin.js")]' \
  /path/to/opencode.json > opencode.json.tmp && mv opencode.json.tmp opencode.json

# Graphify (inside the container):
graphify uninstall --platform opencode

# Caveman (inside the container): run its uninstaller from a clone, or delete by hand
rm -rf ~/.config/opencode/plugins/caveman ~/.config/opencode/skills/caveman* \
       ~/.config/opencode/skills/cavecrew ~/.config/opencode/commands/caveman* \
       ~/.config/opencode/agents/cavecrew-*
# and delete the block between the <!-- caveman-begin --> / <!-- caveman-end --> markers in AGENTS.md
```

> The entrypoint re-adds bundled plugins on every start. To remove them permanently, rebuild without them (see [Configuration](configuration.md#bundled-plugins)) or unset them in a post-start step.

## 6. Remove local DMR models (optional)

```bash
docker model rm ai/smollm2
docker model rm ai/qwen2.5-coder
```

## 7. Remove the Unity bridge (optional)

Only applies when you used the [Unity CLI integration](unity.md).

Stop the running bridge process (`Ctrl+C` in its window) and delete its runtime state:

```bash
# From WSL:
rm -rf ~/.unity-bridge
```

```powershell
# And/or from Windows, if you started it there at least once:
del %USERPROFILE%\.unity-bridge\token
rmdir %USERPROFILE%\.unity-bridge
```

`~/.unity-bridge` holds the auth token and the last persisted path map. The bridge script itself lives inside `$SAFE_CODE_HOME/bridge/` (removed in step 1) or your repo clone (removed in step 7).

If you enabled mirrored networking just for the bridge, optionally revert by deleting the `[wsl2]` block you added to `%USERPROFILE%\.wslconfig` and running `wsl --shutdown`.

## 8. Remove the repository

```bash
cd ..
rm -rf safe-opencode
```
