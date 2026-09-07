# Configuration

## Environment variables

All configuration is done through environment variables, typically set in a `.env` file.

### Build settings

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_VERSION` | Node.js base image tag | `alpine` |
| `PNPM_VERSION` | pnpm version to install | `latest` |
| `OPENCODE_VERSION` | opencode-ai version to install | `latest` |
| `GRAPHIFY_VERSION` | graphify version baked into the image | `latest` |
| `ENV_FILE` | Path to env file (docker-compose only) | `.env` |

### Permissions

| Variable | Description | Default |
|----------|-------------|---------|
| `OPENCODE_PERMISSION_READ` | File read permission | `ask` |
| `OPENCODE_PERMISSION_EDIT` | File edit/write/patch permission | `ask` |
| `OPENCODE_PERMISSION_BASH` | Shell command permission | `ask` |
| `OPENCODE_PERMISSION_GLOB` | File pattern matching permission | `ask` |
| `OPENCODE_PERMISSION_GREP` | Content search permission | `ask` |
| `OPENCODE_PERMISSION_LIST` | Directory listing permission | `ask` |
| `OPENCODE_PERMISSION_WEBFETCH` | URL fetching permission | `ask` |
| `OPENCODE_PERMISSION_WEBSEARCH` | Web search permission | `ask` |
| `OPENCODE_PERMISSION_TASK` | Subagent task permission | `ask` |
| `OPENCODE_PERMISSION_EXTERNAL_DIRECTORY` | Access outside workspace | `ask` |

Permission values:
- `ask` - Prompt for approval each time
- `allow` - Always permitted
- `deny` - Always blocked

Additional permissions available in `opencode.json` (not exposed as env vars):
- `skill` - Skills
- `lsp` - Language server
- `question` - Asking user questions
- `todowrite` - Todo list
- `doom_loop` - Loop prevention

### Model settings

| Variable | Description | Default |
|----------|-------------|---------|
| `OPENCODE_MODEL` | Cloud model identifier (e.g., `anthropic/claude-3-opus`) | (none) |
| `OPENCODE_LOCAL_MODEL_URL` | Docker Model Runner API URL | (none) |

When `OPENCODE_LOCAL_MODEL_URL` is set, `OPENCODE_MODEL` is treated as a local model name (e.g., `ai/smollm2`). The entrypoint generates a provider config using the `@ai-sdk/openai-compatible` package.

DMR URLs from inside the container:
- Docker Desktop: `http://model-runner.docker.internal:12434`
- Docker Engine: `http://172.17.0.1:12434` or `http://model-runner.docker.internal:12434` (with `extra_hosts`)

### API keys

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `OPENAI_API_KEY` | OpenAI API key |
| `GOOGLE_API_KEY` | Google AI API key |

API keys are passed into the container at runtime. Credentials entered via `/connect` in opencode are persisted in the `opencode-auth` Docker volume at `~/.local/share/opencode`.

## Presets

Three presets are included:

| Preset | File | Description |
|--------|------|-------------|
| Safe | `.env.safe` | All permissions set to `ask` |
| Auto | `.env.auto` | All permissions set to `allow` |
| Balanced | `.env.balanced` | Read/glob/grep/list `allow`, others `ask` |

Create your own by copying and modifying any preset.

## Bundled plugins

The image pre-registers three plugins in opencode's global config:

- **Ponytail** (`@dietrichgebert/ponytail`) and **DCP** (`@tarquinen/opencode-dcp`) are added to the `plugin` array of `opencode.json` — opencode auto-installs them from npm on launch.
- **Graphify** is installed as a skill (`~/.config/opencode/skills/graphify`) plus the `graphify` CLI (uv-managed, `~/.config/opencode/bin`), synced into the config volume on every container start.

The entrypoint merges the bundled plugins into any existing `plugin` array (without removing your own entries), so pre-existing configs get them too.

Skills shipped in the image (`skills/` directory in the repo, e.g. the `pnpm` skill) are re-copied into the config volume on every start, so image updates always win over stale volume copies.

## opencode.json

The entrypoint generates an `opencode.json` config file from environment variables on first run. If a config file already exists (from a previous session), it is preserved and only the bundled `plugin` entries are merged in. To force regeneration, remove the config volume:

```bash
docker volume rm opencode-config
```
