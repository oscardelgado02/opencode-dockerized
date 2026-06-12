# Uninstallation

## 1. Remove the safe-code script and project files

System-wide:

```bash
sudo rm /usr/local/bin/safe-code
sudo rm -rf /usr/local/share/safe-code
```

Or for your user only:

```bash
rm ~/.local/bin/safe-code
rm -rf ~/.local/share/safe-code
```

## 2. Stop and remove containers

```bash
docker compose down
```

## 3. Remove Docker images

```bash
docker rmi safe-opencode
```

## 4. Remove volumes

This deletes persisted config, credentials (including API keys), and cached data:

```bash
docker volume rm opencode-config opencode-auth opencode-cache
docker volume rm safe-opencode_opencode-config safe-opencode_opencode-auth safe-opencode_opencode-cache
```

Or remove all at once via compose:

```bash
docker compose down -v
```

## 5. Remove local DMR models (optional)

```bash
docker model rm ai/smollm2
docker model rm ai/qwen2.5-coder
```

## 6. Remove the repository

```bash
cd ..
rm -rf safe-opencode
```
