# Installation

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (v20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2+, optional)
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

Edit `.env` to set your UID/GID and API keys:

```bash
# Find your UID/GID
id -u   # e.g., 1000
id -g   # e.g., 1000
```

Add your API keys to `.env`:

```
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GOOGLE_API_KEY=...
```

## 3. Install the safe-code script

System-wide:

```bash
sudo cp safe-code /usr/local/bin/
sudo chmod +x /usr/local/bin/safe-code
```

Or for your user only:

```bash
mkdir -p ~/.local/bin
cp safe-code ~/.local/bin/
chmod +x ~/.local/bin/safe-code
export PATH="$HOME/.local/bin:$PATH"
```

## 4. Build the Docker image

The image builds automatically on first run, or build manually:

```bash
safe-code --build
```

Or directly with Docker:

```bash
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t safe-opencode .
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
