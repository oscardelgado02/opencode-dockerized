# Security

## Container hardening

This setup applies multiple layers of security:

- **Non-root user**: The container runs as an unprivileged user (`coder`) with your host UID/GID, preventing root-level access.
- **Read-only filesystem**: The container's root filesystem is mounted read-only. Only `/tmp`, `/workspace`, and the config/auth/cache volumes are writable.
- **No new privileges**: The `no-new-privileges` security option prevents the process from gaining additional privileges via setuid/setgid binaries.
- **Dropped capabilities**: All Linux capabilities are dropped (`--cap-drop=ALL`), removing the ability to perform privileged operations.
- **Resource limits**: Memory (512MB), CPU (1 core), and PID (100 processes) limits prevent resource exhaustion.
- **Package integrity**: Uses pnpm for installation with integrity checksums instead of piping scripts from the internet.

## Permission model

OpenCode's permission system controls what the AI agent can do:

| Permission | Controls |
|-----------|----------|
| `read` | Reading file contents |
| `edit` | Editing, writing, and patching files |
| `bash` | Running shell commands |
| `glob` | File pattern matching |
| `grep` | Content search with regex |
| `list` | Directory listing |
| `webfetch` | Fetching URLs |
| `websearch` | Web searches |
| `task` | Spawning subagent tasks |
| `external_directory` | Accessing paths outside workspace |

Each can be set to `ask` (prompt), `allow` (always permit), or `deny` (always block).

Additional permissions (configured directly in `opencode.json`):
- `skill` - Using skills
- `lsp` - Language server operations
- `question` - Asking user questions
- `todowrite` - Managing todo lists
- `doom_loop` - Loop prevention prompts

## Recommendations

- Use `--safe` (or `.env.safe`) when working with untrusted codebases.
- Use `--balanced` for everyday development.
- Use `--auto` only in trusted, isolated environments (CI/CD, throwaway containers).
- Never run with `--auto` on production systems or with access to sensitive data.
- Review the workspace mount path carefully - the container has read-write access to it.

## API key security

API keys are passed as environment variables and stored in the container's config and auth volumes. They are not baked into the Docker image. The volumes are only accessible to the container user.
