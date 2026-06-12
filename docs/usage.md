# Usage

## Basic usage

Run with the safe preset (all permissions require approval):

```bash
safe-code
```

## Presets

```bash
safe-code --safe        # All permissions require approval (most secure)
safe-code --auto        # All permissions pre-approved (fastest)
safe-code --balanced    # Read/search allowed, writes need approval
```

## Custom env file

```bash
safe-code --env-file .env.custom
```

If no `--env-file` or preset is specified, `.env` in the script directory is used automatically.

## Working directory

By default, `safe-code` mounts your current working directory into the container as `/workspace`. You can override this:

```bash
safe-code --workdir /path/to/your/project
```

## Using a specific cloud model

```bash
safe-code --model anthropic/claude-3-opus
safe-code --model openai/gpt-4
```

## Using a local model via Docker Model Runner

[Docker Model Runner (DMR)](https://docs.docker.com/ai/model-runner/) runs AI models locally and exposes an OpenAI-compatible API. No separate container needed.

First, make sure DMR is enabled (see [Docker Model Runner setup](#docker-model-runner-setup) below), then pull a model:

```bash
docker model pull ai/smollm2
docker model pull ai/qwen2.5-coder
docker model pull ai/llama3.2
```

Then run OpenCode with the local model:

```bash
safe-code --local-model ai/smollm2
safe-code --local-model ai/qwen2.5-coder
```

You can also specify a custom DMR URL (default: `http://model-runner.docker.internal:12434`):

```bash
safe-code --local-model ai/smollm2 --dmr-url http://172.17.0.1:12434
```

### Docker Model Runner setup

**Docker Desktop:**
1. Go to Settings > AI tab
2. Enable "Docker Model Runner"
3. Optionally enable "host-side TCP support" for access from host processes

**Docker Engine (Linux):**
```bash
sudo apt-get install docker-model-plugin   # Ubuntu/Debian
# or
sudo dnf install docker-model-plugin       # Fedora/RHEL
```

Verify it works:
```bash
docker model version
docker model ls
```

## Rebuilding the image

```bash
safe-code --build
```

## Docker Compose

The `safe-code` script uses Docker Compose internally. The workspace volume is mounted by the script at runtime, so using `docker compose run` directly requires you to pass the volume mount manually:

```bash
# Run with a specific env file
ENV_FILE=.env.auto docker compose run --rm -v "$(pwd):/workspace:rw" opencode

# Run with a local model
OPENCODE_MODEL=ai/smollm2 OPENCODE_LOCAL_MODEL_URL=http://model-runner.docker.internal:12434 docker compose run --rm -v "$(pwd):/workspace:rw" opencode
```
