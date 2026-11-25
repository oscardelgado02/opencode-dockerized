# Updating

## Why `/update` doesn't work

OpenCode is installed root-owned at image build time and the container is
ephemeral (`docker compose run --rm`). Anything updated inside a running
container is lost on exit. Updating OpenCode means rebuilding the image.

All commands below use `$SAFE_CODE_HOME` — the directory `install.sh` copied
the project to (`~/.local/share/safe-code` for `--user` installs,
`/usr/local/share/safe-code` for system installs).

## Update OpenCode to the latest version

```bash
safe-code --upgrade
```

`--upgrade` rebuilds the image with a cache-busting build arg, so npm resolves
the newest version, then starts opencode as usual. The image records the
installed version in `/usr/local/share/opencode-version`.

Without `--upgrade`, the installed version stays frozen at the last build —
`safe-code --build` alone is not enough, because Docker reuses the cached
install layer unless the build args change. If `.env` pins
`OPENCODE_VERSION=<version>`, `--upgrade` installs that pinned version, not
the newest release.

Manual equivalent (also refreshes the base images):

```bash
docker compose -f "$SAFE_CODE_HOME/docker-compose.yml" build --pull --no-cache
safe-code
```

## Update to a pinned version

Pin a version in `$SAFE_CODE_HOME/.env` for reproducible builds:

```bash
npm view @opencode/cli version        # find the latest version
echo "OPENCODE_VERSION=<version>" >> "$SAFE_CODE_HOME/.env"
safe-code --build
```

Changing the build arg busts Docker's cache automatically.

## Verify

```bash
docker compose -f "$SAFE_CODE_HOME/docker-compose.yml" run --rm opencode opencode --version
```

## Update the safe-code wrapper itself

Needed only when the repository files changed (entrypoint, skills, shims):

```bash
cd <your-clone>
git pull
cp "$SAFE_CODE_HOME/.env" /tmp/safe-code-env.bak   # install.sh overwrites .env!
./install.sh                                        # sudo for system installs
cp /tmp/safe-code-env.bak "$SAFE_CODE_HOME/.env"
safe-code --build
```
