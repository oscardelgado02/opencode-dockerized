# Security

## Container hardening

This setup applies multiple layers of security:

- **Non-root user**: The container runs as an unprivileged user (`coder`), preventing root-level access.
- **Isolated workspace**: Only `/workspace` is mounted from the host with read-write access.
- **Package integrity**: Uses pnpm for installation with integrity checksums instead of piping scripts from the internet.

## Bundled plugins

Three third-party plugins are installed in the global config ([Ponytail](https://github.com/DietrichGebert/ponytail), [DCP](https://github.com/Opencode-DCP/opencode-dynamic-context-pruning), [Caveman](https://github.com/JuliusBrussee/caveman)). Ponytail and DCP come from the public npm registry, caveman cloned from GitHub at the pinned `CAVEMAN_REF` tag — they run with the same privileges as the agent itself. If your threat model requires zero third-party code, remove them (see [Uninstallation](uninstallation.md)).

## Permission model

OpenCode's permission system controls what the AI agent can do:

| Permission | Controls |
|-----------|----------|
| `read` | Reading file contents |
| `edit` | Editing, writing, and patching files |
| `shell` | Running shell commands |
| `glob` | File pattern matching |
| `grep` | Content search with regex |
| `webfetch` | Fetching URLs |
| `websearch` | Web searches |
| `subagent` | Spawning subagents |
| `external_directory` | Accessing paths outside workspace |

Each can be set to `ask` (prompt), `allow` (always permit), or `deny` (always block). Rules are ordered and the last matching rule wins; `OPENCODE_PERMISSION_RULES` appends extra rules after the blanket ones.

Additional v2 permission actions (configured via `OPENCODE_PERMISSION_RULES`):
- `skill` - Using skills
- `question` - Asking user questions

## Recommendations

- Use `--safe` (or `.env.safe`) when working with untrusted codebases.
- Use `--balanced` for everyday development.
- Use `--auto` only in trusted, isolated environments (CI/CD, throwaway containers).
- Never run with `--auto` on production systems or with access to sensitive data.
- Review the workspace mount path carefully - the container has read-write access to it.

## API key security

API keys are passed as environment variables and stored in the container's config and auth volumes. They are not baked into the Docker image. The volumes are only accessible to the container user.
