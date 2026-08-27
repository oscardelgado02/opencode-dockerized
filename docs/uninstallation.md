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

## 5. Remove local DMR models (optional)

```bash
docker model rm ai/smollm2
docker model rm ai/qwen2.5-coder
```

## 6. Remove the Unity bridge (optional)

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

## 7. Remove the repository

```bash
cd ..
rm -rf safe-opencode
```
