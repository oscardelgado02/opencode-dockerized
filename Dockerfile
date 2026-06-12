ARG NODE_VERSION=alpine

FROM node:${NODE_VERSION} AS installer

ARG PNPM_VERSION=latest
ARG OPENCODE_VERSION=latest

RUN if [ "$PNPM_VERSION" = "latest" ]; then \
      npm install -g pnpm; \
    else \
      npm install -g pnpm@${PNPM_VERSION}; \
    fi

ENV SHELL=bash

RUN pnpm setup

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

RUN apk add --no-cache bash libstdc++ libgcc

COPY --from=installer /usr/local/bin/node /usr/local/bin/node
COPY --from=installer /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=installer /root/.local/share/pnpm/ /usr/local/

RUN addgroup -g $GID coder 2>/dev/null; \
    GROUP_NAME=$(getent group $GID | cut -d: -f1); \
    adduser -D -s /bin/sh -u $UID -G "$GROUP_NAME" coder \
    && mkdir -p /home/coder/.config/opencode /home/coder/.local/share/opencode /home/coder/.cache/opencode /workspace \
    && chown -R coder:"$GROUP_NAME" /home/coder /workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER coder
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["opencode"]
