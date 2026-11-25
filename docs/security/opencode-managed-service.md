# Security note: opencode managed service and host loopback exposure

**Scope:** safe-code's Docker setup (`network_mode: host` + opencode's local API server).
**Related:** [docs/security.md](../security.md) (container hardening and permission model).

## What the managed service is

When an opencode instance starts, it launches a local HTTP API server — the "managed service". Its default port is `49374`, and it binds to `127.0.0.1` only. The TUI, the `opencode pair` web flow, and IDE integrations talk to this server. The port can be changed per instance with `opencode service set port <port>`; safe-code persists a per-run port via the `OPENCODE_SERVICE_PORT` environment variable (random per run from `20000`–`30000`, or pinned with `--service-port`), so concurrent instances each get their own port.

The server is not a trivial helper endpoint. Its API includes, among other things:

- `POST /api/shell` — run shell commands
- `POST /api/experimental/fs/write` — write files
- `GET /api/fs/read/*` — read files
- `POST /api/pty` — create PTY sessions (interactive terminals)
- `GET /api/credential` — list stored credentials
- `POST /api/session/{id}/permission` — reply to (i.e. approve) permission prompts
- `PATCH /api/experimental/config` — change configuration

## Exposure analysis

### Not exploitable from the network

The server binds to `127.0.0.1` only. Nothing on the LAN or the internet can reach it directly, and the random per-run port range (`20000`–`30000`) stays inside the loopback bind. There is no remote attack path through this server as long as the loopback bind is not changed.

### Reachable by any local process

Because `docker-compose.yml` sets `network_mode: host`, the container's "loopback" is the host's real loopback interface. Any process running on the host — under any user account — can connect to the managed service port and call the full API. Concretely, a hostile or compromised local process can:

1. Run shell commands inside the container (`/api/shell`), operating on the mounted `/workspace` directory with the `coder` user's permissions (read-write on the workspace mount).
2. Read and write files through the filesystem routes.
3. Answer `ask` permission prompts itself via the permission routes. The interactive "ask" approval in the TUI is a UI boundary, not a security boundary against host-local processes: anything that can reach the port can approve its own requests.
4. Read the credential list and attempt to extract stored API keys.
5. Use `opencode pair`-style one-time connect links if it can reach the server before the legitimate user (`/auth/connect/{code}` links work once and expire in 5 minutes).

### What this does NOT mean

- It is not remote code execution. It requires an attacker-controlled process already running on the same machine.
- The container's permission model (`--safe`, `--balanced`) still governs what the *agent* does. What it does not do is protect the agent's control plane (the API server) from the host.
- The workspace mount itself is a comparable or larger exposure: the container has read-write access to whatever directory safe-code was launched from, and a host process could often just read those files directly.

## Severity assessment

- **Personal single-user machine, no untrusted local software:** low. There is no realistic attacker position beyond "already owns my user account", at which point the API server adds little.
- **Shared/multi-user host, or a host where untrusted binaries are run:** moderate. Any local user or malicious process gains read-write access to the workspace mounted for safe-code and can drive or auto-approve the agent. Running safe-code with `--auto` on such a host removes even the human-in-the-loop friction.
- **Server/CI environments:** treat as host-trust tooling. Only run on machines where every local process is within the trust boundary.

## Mitigations and recommendations

1. **Keep the loopback bind.** Never bind the managed service to `0.0.0.0` or a non-loopback interface. This is the single control that keeps the issue network-safe.
2. **Per-instance ports** (implemented in safe-code): each concurrent instance binds its own port on loopback. This resolves the port-collision failure and does not change exposure.
3. **Bridge networking alternative (not implemented):** removing `network_mode: host` would isolate each container's loopback and eliminate host-process access, but likely breaks `opencode pair` callbacks, Docker Model Runner access, and the Unity bridge URL patterns. Only consider this if genuine host-process isolation is required.
4. **Document the trust model:** safe-code instances should be treated as host-trust tools. The `--auto` preset is appropriate only on machines where host-local processes are trusted.
5. **Credential hygiene:** API keys are stored in the `opencode-auth` volume and visible through the credential API to anything that can reach the port. On shared hosts, prefer keys scoped to the project and rotate them.

## Changelog reference for the fix

- `safe-code`: `--service-port <port>` flag; random service port per run (`20000`–`30000`, below the typical ephemeral port range); precedence flag > `OPENCODE_SERVICE_PORT` env > random.
- `docker-compose.yml`: `OPENCODE_SERVICE_PORT` passthrough.
- `entrypoint.sh`: runs `opencode service set port` at container start (idempotent, persisted in the instance's config volume).
- `docs/usage.md`: "Running multiple instances" section.
- `docs/troubleshooting.md`: entry for the port-in-use error and stale-volume warnings.
