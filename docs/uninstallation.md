# Uninstallation

## 1. Remove the safe-code script and project files

System-wide:

```bash
sudo rm /usr/local/bin/safe-code
sudo rm -rf /usr/local/share/safe-code
```

Or for your user only:

```bash
rm ~/.local/bin/safe-code
rm -rf ~/.local/share/safe-code
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

Ponytail and DCP live in the `plugin` array of `~/.config/opencode/opencode.json` in the config volume; graphify also installs a skill and the `graphify` CLI into the same volume. Removing them individually:

```bash
# Inside the container (or any editor on the volume): delete the plugin entries
# you don't want, e.g. everything except "@custom/...":
jq '.plugin = [.plugin[] | select(. != "@dietrichgebert/ponytail" and . != "@tarquinen/opencode-dcp")]' \
  /path/to/opencode.json > opencode.json.tmp && mv opencode.json.tmp opencode.json

# Graphify (inside the container):
graphify uninstall --platform opencode
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
