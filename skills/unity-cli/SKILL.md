---
name: unity-cli
description: Build, test and manage Unity projects from this container by running the Unity CLI on the host machine through the `unity` bridge command. Use when the user asks to build Unity targets, run Unity commands, check the Unity bridge, or troubleshoot Unity CLI errors.
license: MIT
compatibility: opencode
metadata:
  scope: unity-docker-bridge
---

# Unity CLI (host bridge)

The `unity` command available in this container does NOT run Unity locally.
It forwards your arguments over HTTP to a small bridge (`unity-bridge.mjs`) running on the
user's host machine (Windows), which executes the real Unity CLI there and returns the result.

Key facts:
- Exit codes are propagated faithfully from the host: `0` success, other = failure,
  `124` means the host command hit the timeout (`UNITY_TIMEOUT_MS`, default 30 min).
- stdout/stderr are streamed back separated — same as running Unity natively.
- Every call is gated by opencode's normal bash permissions.

## First check connectivity

If any unity call fails with "cannot connect", or before long workflows, run:

```bash
unity bridge-health
```

It prints the bridge status and the executable it will invoke. Tell the user to start the
bridge if unreachable: `node bridge/unity-bridge.mjs` (on their Windows host).

## Working directory matters

Unity resolves project paths relative to cwd. The container cwd `/workspace/...` is mapped to a
host path only if the bridge was started with `--path-map "/workspace=C:\path\to\project"`.
If you see "Directory not found on host", tell the user to add/update that mapping rather than
guessing absolute Windows paths yourself.

## Typical invocations

```bash
unity --version
unity build -target StandaloneWindows64      # target names depend on host's Unity version
```

Prefer relative paths from the current project root; avoid writing files to fixed host drive
letters — always stay inside the mapped working directory.

## Error playbook

| Symptom | Cause | Fix |
|---|---|---|
| `cannot connect to bridge` | bridge not running / wrong URL/port | Start `node bridge/unity-bridge.mjs`; verify `UNITY_BRIDGE_URL` |
| HTTP 401 in output | token mismatch | Restart bridge, copy fresh token into `UNITY_BRIDGE_TOKEN` |
| `Directory not found on host` | cwd not path-mapped | Ask user for `--path-map` value; rerun after they restart bridge |
| exit 124 | timeout exceeded | Raise `UNITY_TIMEOUT_MS`; don't retry blindly — check partial state first |
| `Failed to start '<cmd>'` | wrong executable configured on bridge | Host must pass correct `--command /path/to/cli.exe` |

Long builds produce lots of output progressively on the host but are returned once finished;
be patient and do not parallelize multiple heavy builds through one bridge.
