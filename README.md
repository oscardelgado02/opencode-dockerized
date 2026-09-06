# Safe OpenCode Docker Setup

A secure Docker container for running [OpenCode](https://opencode.ai) with configurable permissions, persistent config, and optional local model support via [Docker Model Runner](https://docs.docker.com/ai/model-runner/).

## Quick start

```bash
git clone git@github.com:oscardelgado02/opencode-dockerized.git safe-opencode
cd safe-opencode
cp .env.safe .env
# Edit .env with your API keys

sudo mkdir -p /usr/local/share/safe-code
sudo cp -r Dockerfile docker-compose.yml entrypoint.sh shims skills bridge .env.safe .env.auto .env.balanced /usr/local/share/safe-code/
[ -f .env ] && sudo cp .env /usr/local/share/safe-code/
sudo cp safe-code /usr/local/bin/
sudo chmod +x /usr/local/bin/safe-code
echo 'export SAFE_CODE_HOME=/usr/local/share/safe-code' >> ~/.bashrc
source ~/.bashrc

safe-code
```

> The `bridge/` folder ships with the installation, so an up-to-date Unity bridge always lives at `$SAFE_CODE_HOME/bridge/unity-bridge.mjs`.

## Security features

- Non-root user
- Configurable permission model (ask/allow/deny per operation)
- pnpm installation with integrity checksums
- Persistent config and auth volumes (provider credentials survive restarts)

## Presets

| Preset | Flag | Description |
|--------|------|-------------|
| Safe | `--safe` | All permissions require approval |
| Auto | `--auto` | All permissions pre-approved |
| Balanced | `--balanced` | Read/search allowed, writes need approval |

## Local models

> [!IMPORTANT]  
> To use Docker Model Runner, make sure to uncomment `OPENCODE_LOCAL_MODEL_URL` environment variable in `.env` file before doing the build.
> 
> Also, make sure to add enough context window to the model, for example:
> 
> ```bash
> docker model configure qwen3.5:9B-UD-Q4_K_XL --context-size 131072
> ```

Uses [Docker Model Runner](https://docs.docker.com/ai/model-runner/) for local inference (OpenAI-compatible API, no extra container needed):

```bash
docker model pull ai/smollm2
safe-code --local-model ai/smollm2
```

## Unity CLI integration

Runs the Unity CLI installed on your host machine from inside the container via a small local bridge — no need to install Unity in Docker:

```powershell
# On the host (Windows)
node bridge\unity-bridge.mjs
```

Then set `UNITY_BRIDGE_TOKEN` in `.env` and call `unity build ...` from inside opencode. See [Unity integration](docs/unity.md).

The image can also ship a `unity-cli` agent skill (installed into opencode's config on start) so the AI knows how to use the bridge — timeouts, error playbook, path mapping. It is **not** included by default; opt in with `--unity`, or `WITH_UNITY=1` in `.env`.

Reset to a clean slate (erases config/auth/cache volumes and rebuilds):

```bash
safe-code --reset
```

## Documentation

- [Installation](docs/installation.md) - Prerequisites, setup, and version pinning
- [Usage](docs/usage.md) - Running, presets, models, Docker Compose
- [Configuration](docs/configuration.md) - Environment variables, permissions, presets
- [Security](docs/security.md) - Hardening details and recommendations
- [Troubleshooting](docs/troubleshooting.md) - Common issues and fixes
- [Uninstallation](docs/uninstallation.md) - Complete removal steps

## Resources

- [OpenCode Documentation](https://opencode.ai/docs)
- [OpenCode GitHub](https://github.com/anomalyco/opencode)
- [Docker Model Runner](https://docs.docker.com/ai/model-runner/)
