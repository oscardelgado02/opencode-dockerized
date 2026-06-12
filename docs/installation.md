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

System-wide:

```bash
sudo mkdir -p /usr/local/share/safe-code
sudo cp Dockerfile docker-compose.yml entrypoint.sh .env.safe .env.auto .env.balanced /usr/local/share/safe-code/
[ -f .env ] && sudo cp .env /usr/local/share/safe-code/
sudo cp safe-code /usr/local/bin/
sudo chmod +x /usr/local/bin/safe-code
echo 'export SAFE_CODE_HOME=/usr/local/share/safe-code' >> ~/.bashrc
source ~/.bashrc
```

Or for your user only:

```bash
mkdir -p ~/.local/share/safe-code
cp Dockerfile docker-compose.yml entrypoint.sh .env.safe .env.auto .env.balanced ~/.local/share/safe-code/
[ -f .env ] && cp .env ~/.local/share/safe-code/
mkdir -p ~/.local/bin
cp safe-code ~/.local/bin/
chmod +x ~/.local/bin/safe-code
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

> **Note:** If you use `zsh` or another shell, replace `~/.bashrc` with `~/.zshrc` or the appropriate profile file.

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
PNPM_VERSION=8.15.4
OPENCODE_VERSION=0.0.0-alpha.56
```

Then rebuild:

```bash
safe-code --build
```
