# Safe OpenCode Docker Setup

This setup provides a secure Docker container for running [OpenCode](https://opencode.ai) with restricted permissions. OpenCode will always ask for explicit approval before editing files, running commands, or accessing the network.

---

## Quick Start

### 1. Build the Docker Image

```bash
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) --no-cache -t safe-opencode .
```

- `--build-arg UID=$(id -u)`: Matches the container user to your host UID.
- `--build-arg GID=$(id -g)`: Matches the container group to your host GID.
- `--no-cache`: Ensures a fresh build.
- `-t safe-opencode`: Tags the image for easy reference.

---

### 2. Add the Alias
Add this to your `~/.bashrc` or `~/.zshrc`:

```bash
alias safe-opencode='docker run --rm -it \
  -v "$HOME/.config/opencode/opencode.json:/home/coder/.config/opencode/opencode.json:ro" \
  -v "$(pwd):/workspace:rw" \
  safe-opencode'
```

- `--rm`: Removes the container after exit.
- `-it`: Interactive terminal.
- `-v "$HOME/.config/opencode/opencode.json:..."`: Mounts your config file (read-only).
- `-v "$(pwd):/workspace:rw"`: Mounts your current directory for read/write access.

Reload your shell:

```bash
source ~/.bashrc  # or source ~/.zshrc
```

---
### 3. Run OpenCode

```bash
safe-opencode
```

or:

```bash
docker run --rm -it -e HOME=/home/coder -v "$(pwd):/workspace:rw" safe-opencode
```

---

## Files Explained

### 🐳 `Dockerfile`
- Multi-stage build: Reduces image size by discarding build-time dependencies.
- Non-root user: Runs as a non-root user (`coder`) with your host UID/GID.
- OpenCode via pnpm: Installs OpenCode securely using `pnpm`.
- Config file: Copies `opencode.json` to enforce restricted permissions.

#### Stages:
1. Base: Installs Node.js, npm, and dependencies.
2. Installer: Installs OpenCode using `pnpm`.
3. Final: Copies only necessary files and sets up the non-root user.

---
### `opencode.json`

```bash
{
  "$schema": "https://opencode.ai/opencode.json",
  "permission": {
    "edit": "ask",
    "bash": "ask",
    "read": "ask",
    "write": "ask",
    "run": "ask",
    "fileSystem": "ask",
    "network": "ask"
  }
}
```

- All permissions set to `"ask"`: OpenCode will prompt you before performing any sensitive action.

| Permission   | Description                          |
|--------------|--------------------------------------|
| `edit`         | File edits                           |
| `bash`         | Shell command execution              |
| `read`         | Reading files                        |
| `write`        | Writing files                        |
| `run`          | Running scripts/executables          |
| `fileSystem`   | Filesystem access (e.g., `ls`)         |
| `network`      | Network access (e.g., `curl`)          |

---

## Customization

### Update Permissions
Edit `opencode.json` to adjust permissions. Example:


```bash
{
  "$schema": "https://opencode.ai/opencode.json",
  "permission": {
    "edit": "ask",
    "bash": "deny",
    "read": "allow",
    "write": "ask",
    "run": "deny",
    "fileSystem": "ask",
    "network": "deny"
  }
}
```

### Rebuild the Image
After updating the config:

```bash
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) --no-cache -t safe-opencode .
```

---
## Tips

### Persist OpenCode Cache
Add a volume for the cache directory:

```bash
alias safe-opencode='docker run --rm -it \
  -v "$HOME/.config/opencode/opencode.json:/home/coder/.config/opencode/opencode.json:ro" \
  -v "$HOME/.cache/opencode:/home/coder/.cache/opencode" \
  -v "$(pwd):/workspace:rw" \
  safe-opencode'
```

### Use a Specific Version
Update the Dockerfile to pin a version:

```bash
RUN pnpm add -g opencode-ai@1.2.3
```

---

## Resources
- [OpenCode Documentation](https://opencode.ai/docs)
- [OpenCode GitHub](https://github.com/anomalyco/opencode)