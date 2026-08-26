# Unity CLI integration

Run the Unity CLI installed on your **Windows host** from inside the safe-opencode container.

## Why a bridge instead of installing Unity in the container?

| | Bridge (recommended) | Install in container |
|---|---|---|
| Image size | ~0 MB extra | +several GB |
| License | Reuses host license | Needs its own activation |
| Editor/GUI | Already running on host | Not supported on Alpine |
| Version sync | Always matches host | Must rebuild on updates |

The container gets a thin `unity` command that transparently forwards to your host's Unity CLI over HTTP.

```
+---------------------+        HTTP          +----------------------+
|  Docker container   |  ----------------->  |   Windows host       |
|  opencode           |  unity <args>        |  unity-bridge.mjs    |
|  shims/unity        |  <-----------------  |  -> runs Unity CLI   |
+---------------------+   JSON result        +----------------------+
     host.docker.internal
```

## Setup

### 1. Start the bridge on the host (one-time per session)

Requires Node.js >= 18 (`winget install OpenJS.NodeJS.LTS`):

```powershell
node bridge\unity-bridge.mjs
```

First run generates an auth token at `%USERPROFILE%\.unity-bridge\token` and prints it. Leave the window open.

Useful options:

```powershell
# Point at a specific CLI path, restrict commands, map paths
node bridge\unity-bridge.mjs `
  --command "C:\Program Files\Unity\Hub\Editor\<version>\Editor\Data\Resources\unity.exe" `
  --allow-cmds "build,test,publish" `
  --path-map "/workspace=C:\src\MyGame"
```

| Option | Purpose |
|--------|---------|
| `--port` | Listen port (default 7777) |
| `--command` | Unity CLI executable (default `unity`, must be resolvable by `spawn`) |
| `--token <t>` / `--no-token` | Auth token (auto-generated when omitted) |
| `--allow-cmds <list>` | Whitelist of allowed first arguments |
| `--path-map <pairs>` | Translate container paths, `/container=path\host;/c2=h2` |

### 2. Configure the container

Add to `.env`:

```bash
UNITY_BRIDGE_URL=http://host.docker.internal:7777
UNITY_BRIDGE_TOKEN=<token from step 1>
# Optional: raise for long builds (ms)
# UNITY_TIMEOUT_MS=1800000
```

Or pass at runtime: `safe-code --unity-token <token>`.

If you changed the token, delete it first: `del %USERPROFILE%\.unity-bridge\token`.

### 3. Use it

Inside opencode (or any shell in the container):

```bash
unity --version
unity build -target StandaloneWindows64
bridge-health      # as first arg of `unity`: check bridge connectivity
```

opencode treats these as normal bash calls — they are gated by `OPENCODE_PERMISSION_BASH` like every other command.

## The unity-cli skill

The image can ship an [agent skill](https://opencode.ai/docs/skills/) (`skills/unity-cli/SKILL.md` in the repo). On every start the entrypoint installs it into the persistent config volume at `~/.config/opencode/skills/unity-cli/`, where opencode discovers it and can load it on demand — so the agent already knows about bridge health checks, timeouts, path mapping, and how to react to each error class.

It is **not** part of the default image. Include/exclude at build time:

```bash
safe-code --unity        # rebuild WITH the unity command + skill (opt-in)
safe-code --no-unity     # build without them (default); entrypoint removes a stale skill on next start
```

Or set `WITH_UNITY=1` in `.env`. Config edits inside the volume get overwritten by image updates; keep custom skills in separate directories.

## Reset everything

Wipes opencode's persistent volumes (config, auth, cache), forces a rebuild, then starts fresh:

```bash
safe-code --reset
```

Equivalent to `docker compose down -v` + rebuild. The bridge on your host is untouched.

## Path mapping

The Unity CLI resolves relative paths against its working directory. Inside the container that is `/workspace/...`, which does not exist on the host. `--path-map` translates them:

```powershell
node bridge\unity-bridge.mjs --path-map "/workspace=C:\src\MyGame"
```

Now `cd /workspace && unity build ...` runs with `C:\src\MyGame` as cwd on the host.

## Security notes

- The bridge binds to `127.0.0.1` only; nothing outside your machine can reach it.
- Every request requires the token header (`x-unity-token`, timing-safe comparison).
- No shell is used server-side (`spawn(shell:false)`); arguments go straight to the Unity executable.
- Output is capped (10 MB/stream). Commands time out after `timeoutMs`.
- For shared machines set `--allow-cmds` so only intended subcommands can run.
