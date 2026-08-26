# Troubleshooting

## Permission denied when accessing files

The container runs as user `coder` (UID 1000). If you have permission issues, ensure your workspace directory is accessible to UID 1000, or rebuild with a different UID/GID:

```bash
docker compose build --build-arg UID=$(id -u) --build-arg GID=$(id -g)
```

## API key not persisting between sessions

API keys and credentials are stored in the `opencode-auth` Docker volume at `~/.local/share/opencode`. Make sure you are using the `safe-code` script or docker-compose (both mount this volume). If you run the container directly with `docker run`, add:

```bash
-v opencode-auth:/home/coder/.local/share/opencode
```

## Can't connect to Docker Model Runner

1. Make sure DMR is enabled:

```bash
docker model version
```

2. Pull a model first:

```bash
docker model pull ai/smollm2
```

3. Verify the model is available:

```bash
docker model ls
```

4. Test connectivity from inside the container:

```bash
docker run --rm --add-host=model-runner.docker.internal:host-gateway \
  alpine sh -c "apk add curl && curl http://model-runner.docker.internal:12434/api/tags"
```

5. On Docker Engine (Linux), the default gateway IP may differ. Try:

```bash
safe-code --local-model ai/smollm2 --dmr-url http://172.17.0.1:12434
```

## Image won't build

Try building with no cache:

```bash
docker compose build --no-cache
```

## Container exits immediately

Run with debug output:

```bash
docker compose run --rm --entrypoint /bin/sh opencode
```

Then manually run `opencode` to see error messages.

## Config file not updating

The entrypoint only generates `opencode.json` if it doesn't already exist. Reset everything instead:

```bash
safe-code --reset
```

Or just remove the config volume: `docker volume rm safe-opencode_opencode-config && safe-code --build`.

## unity-cli skill not showing in opencode

1. Confirm the image was built with Unity: `docker run --rm --entrypoint sh safe-opencode -c 'ls /usr/local/share/opencode-skills'`
2. Check it landed in the volume: `ls ~/.config/opencode/skills/unity-cli` inside the container
3. A `--no-unity` build (the default) removes the skill on next container start, but only if you actually rebuild (`safe-code --no-unity` forces one)

## Start completely fresh

```bash
safe-code --reset   # = docker compose down -v + rebuild + run
```

## Unity CLI: cannot connect to bridge

1. Make sure the bridge is running on the host: `node bridge\unity-bridge.mjs`
2. From inside the container, test connectivity:

```bash
unity bridge-health
```

3. On Docker Engine (Linux) the gateway IP may differ from `host.docker.internal`:

```bash
ip route | grep default   # e.g. 172.17.0.1
safe-code --unity-url http://172.17.0.1:7777
```

## Unity CLI: HTTP 401 or "rejected"

The token in `UNITY_BRIDGE_TOKEN` does not match the bridge's token. The bridge prints its token on startup and stores it at `~/.unity-bridge/token`. If you deleted the file, restart the bridge to generate a new one.

## Unity CLI: "Directory not found on host"

The bridge cannot resolve the container's working directory. Start it with a path map:

```powershell
node bridge\unity-bridge.mjs --path-map "/workspace=C:\src\MyGame"
```

## Unity CLI: "Failed to start '<command>'"

`spawn` could not find the Unity CLI executable. Pass an explicit path:

```powershell
node bridge\unity-bridge.mjs --command "C:\path\to\unity.exe"
```

Note: on Windows a plain command name requires it to be in PATH and spawnable without a shell; `.cmd`/`.bat` wrappers must be invoked via their full path with `--command`.

## Out of memory

Increase the memory limit in `docker-compose.yml` or pass `--memory` to `docker run`:

```yaml
deploy:
  resources:
    limits:
      memory: 1g
```
