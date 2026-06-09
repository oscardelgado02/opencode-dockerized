# ---- Base Stage ----
FROM alpine:3.19 as base

# Install dependencies for Node.js and pnpm
RUN apk add --no-cache --no-cache-dir \
    nodejs \
    npm \
    ca-certificates \
    bash \
    libstdc++ \
    libgcc \
    && rm -rf /var/cache/apk/*

# Install pnpm globally
RUN npm install -g pnpm

# ---- Install OpenCode with pnpm ----
FROM base as installer

# Install OpenCode using pnpm
RUN pnpm add -g opencode-ai

# Verify the installation
RUN opencode --version

# ---- Final Stage ----
FROM alpine:3.19

# Copy the globally installed pnpm and OpenCode binaries
COPY --from=installer /usr/local/bin/pnpm /usr/local/bin/pnpm
COPY --from=installer /usr/local/bin/opencode /usr/local/bin/opencode
COPY --from=installer /usr/local/lib/node_modules /usr/local/lib/node_modules

# Install runtime dependencies
RUN apk add --no-cache --no-cache-dir \
    ca-certificates \
    bash \
    libstdc++ \
    libgcc \
    nodejs \
    && rm -rf /var/cache/apk/*

# Create a non-root user and group
ARG UID=1000
ARG GID=1000

RUN addgroup -g $GID coder 2>/dev/null || \
    GROUP_NAME=$(getent group $GID | cut -d: -f1) && \
    adduser -D -s /bin/sh -u $UID -G "$GROUP_NAME" coder && \
    mkdir -p /home/coder/.config/opencode && \
    chown -R coder:"$GROUP_NAME" /home/coder

# Copy the custom OpenCode config file
COPY opencode.json /home/coder/.config/opencode/opencode.json

# Set the correct ownership for the config file
RUN chown coder:"$GROUP_NAME" /home/coder/.config/opencode/opencode.json

# Set up the workspace
USER coder
WORKDIR /workspace

# Health check (optional)
HEALTHCHECK --interval=30s --timeout=3s \
    CMD [ -x /usr/local/bin/opencode ] || exit 1

# Default command
CMD ["opencode"]