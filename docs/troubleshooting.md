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

The entrypoint only generates `opencode.json` if it doesn't already exist. To regenerate:

```bash
docker volume rm opencode-config
safe-code --build
```

## Out of memory

Increase the memory limit in `docker-compose.yml` or pass `--memory` to `docker run`:

```yaml
deploy:
  resources:
    limits:
      memory: 1g
```
