---
name: pnpm
description: Use pnpm instead of npm for all JavaScript/TypeScript work in this container (installing packages, running project scripts, global installs, creating apps). Always preferred over npm, npx, yarn, or bun.
license: MIT
compatibility: opencode
metadata:
  scope: js-toolchain
---

# pnpm, not npm

This container ships pnpm as the JavaScript package manager. Use `pnpm` for
everything you would reach for `npm`, `yarn`, or `bun` for. Do not run `npm install`
or `npm ci` — they create a different `node_modules` layout and lockfile than the
one this environment is set up around.

Mappings:

| npm | pnpm |
|-----|------|
| `npm install <pkg>` | `pnpm add <pkg>` |
| `npm ci` / `npm install` (project deps) | `pnpm install --frozen-lockfile` |
| `npm run <script>` | `pnpm <script>` (no `run` needed) |
| `npm exec <bin>` / `npx <bin>` | `pnpm <bin>` or `pnpm dlx <bin>` (never installed to disk) |
| `npm i -g <pkg>` | `pnpm add -g <pkg>` |
| `npm test` | `pnpm test` |

Notes:

- If the project has no lockfile yet, plain `pnpm install` creates `pnpm-lock.yaml`.
- If the project already has a `package-lock.json` or `yarn.lock` and no `pnpm-lock.yaml`,
  `pnpm import` converts it — or just use `pnpm install --frozen-lockfile=false` once.
- `pnpm dlx <pkg>` replaces `npx <pkg>`: runs without polluting `node_modules`.
- Global installs go to `/usr/local/bin` (`PNPM_HOME` is set) and are immediately on PATH.
- `pn` and `pnx` are shorthands for `pnpm` and `pnpm dlx`.
- If a project must use a different package manager (e.g. it pins one in
  `package.json > packageManager`), follow the project — the skill is the default, not a law.
