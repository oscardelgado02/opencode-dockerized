FROM alpine:3.19
ARG UID=1000
ARG GID=1000
RUN apk add --no-cache curl ca-certificates bash libstdc++ libgcc \
    && curl -fsSL https://opencode.ai/install | bash \
    && ls -R /root/ \
    && mv /root/.opencode/bin/opencode /usr/local/bin/opencode || echo "File not found!" \
    && apk del curl
RUN addgroup -g $GID coder 2>/dev/null; \
	GROUP_NAME=$(getent group $GID | cut -d: -f1); \
	adduser -D -s /bin/sh -u $UID -G "$GROUP_NAME" coder \
    && mkdir -p /home/coder/.config/opencode \
    && chown -R coder:"$GROUP_NAME" /home/coder
USER coder
WORKDIR /workspace
CMD ["opencode"]