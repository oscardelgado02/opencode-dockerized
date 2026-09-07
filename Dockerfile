ARG NODE_VERSION=alpine

FROM node:${NODE_VERSION} AS installer

ARG PNPM_VERSION=latest
ARG OPENCODE_VERSION=latest

RUN if [ "$PNPM_VERSION" = "latest" ]; then \
      npm install -g pnpm; \
    else \
      npm install -g pnpm@${PNPM_VERSION}; \
    fi

ENV PNPM_HOME=/root/.local/share/pnpm
ENV PATH="/root/.local/share/pnpm/bin:$PATH"

RUN if [ "$OPENCODE_VERSION" = "latest" ]; then \
      pnpm add -g opencode-ai@latest; \
    else \
      pnpm add -g opencode-ai@${OPENCODE_VERSION}; \
    fi && \
    find /root/.local/share/pnpm/global -path '*/node_modules/opencode-ai' -exec sh -c 'cd "{}" && node postinstall.mjs' \;

FROM alpine:latest

ARG UID=1000
ARG GID=1000
ARG WITH_UNITY=0
ARG GRAPHIFY_VERSION=latest

RUN apk add --no-cache bash libstdc++ libgcc jq uv python3 py3-pip

COPY --from=installer /usr/local/bin/node /usr/local/bin/node
COPY --from=installer /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=installer /root/.local/share/pnpm/ /usr/local/
COPY --from=installer /usr/local/bin/pn* /usr/local/bin/

# The pn* glob above only lands pnpm's sidecar shims (pn/pnpx/pnx), not the CLI
# itself; pnpm.cjs also lacks the exec bit, so link the executable .mjs entry.
RUN ln -sf /usr/local/lib/node_modules/pnpm/bin/pnpm.mjs /usr/local/bin/pnpm

# PNPM_HOME points at the merged-in installer layout so `pnpm add -g` shims
# land in /usr/local/bin (already on PATH).
ENV PNPM_HOME=/usr/local

RUN addgroup -g $GID coder 2>/dev/null; \
    GROUP_NAME=$(getent group $GID | cut -d: -f1); \
    adduser -D -s /bin/sh -u $UID -G "$GROUP_NAME" coder \
    && mkdir -p /home/coder/.config/opencode /home/coder/.local/share/opencode /home/coder/.cache/opencode /workspace \
    && chown -R coder:"$GROUP_NAME" /home/coder /workspace \
    && mkdir -p /usr/local/share/opencode-graphify/skills \
    && chown coder:"$GROUP_NAME" /usr/local/share/opencode-graphify

# graphify runs on uv-managed Python, kept under the (persistent) config dir.
# A staging copy lives outside the config volume so the entrypoint can sync it
# into pre-existing volumes and refresh them on image updates.
ENV UV_TOOL_DIR=/home/coder/.config/opencode/uv-tools \
    UV_TOOL_BIN_DIR=/home/coder/.config/opencode/bin \
    UV_PYTHON_INSTALL_DIR=/home/coder/.config/opencode/uv-python

RUN uv tool install graphifyy@${GRAPHIFY_VERSION} && \
    cd /tmp && HOME=/home/coder PATH=/home/coder/.config/opencode/bin:$PATH graphify install --platform opencode && \
    cp -R /home/coder/.config/opencode/skills/graphify /usr/local/share/opencode-graphify/skills/graphify

# Symlinks so `graphify` works from any shell, even before the config volume exists.
RUN ln -sf /home/coder/.config/opencode/bin/graphify /usr/local/bin/graphify && \
    ln -sf /home/coder/.config/opencode/bin/graphify-mcp /usr/local/bin/graphify-mcp

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY skills/ /usr/local/share/opencode-skills/
COPY shims/unity /usr/local/bin/unity
RUN if [ "$WITH_UNITY" = "1" ]; then \
      apk add --no-cache curl && chmod +x /usr/local/bin/unity; \
    else \
      rm -f /usr/local/bin/unity && rm -rf /usr/local/share/opencode-skills/unity-cli; \
    fi

USER coder
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["opencode"]
