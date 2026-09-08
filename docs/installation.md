# Installation

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (v20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2+, required)
- [Docker Model Runner](https://docs.docker.com/ai/model-runner/) (optional, for local models)

## 1. Clone the repository

```bash
git clone git@github.com:oscardelgado02/opencode-dockerized.git safe-opencode
cd safe-opencode
```

## 2. Set up your environment

Copy a preset to `.env` or use the example template:

```bash
# Most secure - all permissions require approval
cp .env.safe .env

# Or for fast, uninterrupted workflows
cp .env.auto .env

# Or a middle ground - reads allowed, writes need approval
cp .env.balanced .env
```

Edit `.env` to add your API keys:

```
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GOOGLE_API_KEY=...
```

## 3. Install the safe-code script

One command from the repo root:

```bash
./install.sh
```

That copies everything to `/usr/local/share/safe-code`, installs the `safe-code` launcher to `/usr/local/bin`, and adds `SAFE_CODE_HOME` to your shell config (needs sudo).

For a user-only install (no sudo):

```bash
./install.sh --user
```

> **Note:** If you use `zsh` or another shell, the installer updates `~/.zshrc` too. Reopen your shell or `source ~/.bashrc` afterwards.

## 4. Build the Docker image

The image builds automatically on first run, or build manually:

```bash
safe-code --build
```

Or directly with Docker Compose:

```bash
docker compose build
```

## Pinning specific versions

By default, the latest versions of Node.js, pnpm, and opencode-ai are used. To pin specific versions, set them in your `.env` file:

```
NODE_VERSION=alpine
PNPM_VERSION=10.17.0
OPENCODE_VERSION=1.18.29
GRAPHIFY_VERSION=0.9.55
CAVEMAN_REF=v2.6.0
```

> **Note:** `GRAPHIFY_VERSION` pins the graphify CLI version baked into the image, `CAVEMAN_REF` pins the caveman plugin's GitHub tag. Ponytail and DCP are installed by opencode itself from the `plugin` array in `opencode.json` — pin them there if needed (e.g. `["@dietrichgebert/ponytail@4.9.0"]`).

## What's in the image

Runtime tools available to the agent: `node`, `pnpm`, `python3`, `pip3`, `uv`, `jq`, `graphify`, plus opencode itself. JavaScript packages are installed via pnpm with registry integrity checksums. Bundled skills (`pnpm`, plus `unity-cli` when built with `WITH_UNITY=1`) are synced into the config volume on every start.

Then rebuild:

```bash
safe-code --build
```
