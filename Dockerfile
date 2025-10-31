# syntax=docker/dockerfile:1.7

ARG UPSTREAM_REF=v0.2.0
ARG UPSTREAM_TARBALL=""

## Builder
FROM golang:1.25.1-alpine AS builder

ARG UPSTREAM_REF
ARG UPSTREAM_TARBALL
WORKDIR /src
RUN apk add --no-cache ca-certificates wget build-base

# Fetch source
RUN set -eux; \
    tarball="${UPSTREAM_TARBALL}"; \
    ref_path="${UPSTREAM_REF}"; \
    if [ -z "${tarball}" ]; then \
      case "${ref_path}" in \
        refs/*) : ;; \
        */*) ref_path="refs/heads/${ref_path}" ;; \
        *) ref_path="refs/tags/${ref_path}" ;; \
      esac; \
      tarball="https://codeload.github.com/spiercey/plexamp-tui/tar.gz/${ref_path}"; \
    fi; \
    wget -O src.tar.gz "${tarball}"

# Extract into /src/app
RUN mkdir app && tar -xzf src.tar.gz -C app --strip-components=1
WORKDIR /src/app

# Build
ENV CGO_ENABLED=0
RUN go build -o plexamp-tui
RUN install -Dm755 plexamp-tui /out/plexamp-tui && \
    install -Dm644 LICENSE /out/LICENSE

## Runtime
FROM alpine:3.22

RUN apk add --no-cache ca-certificates tzdata su-exec
USER root
WORKDIR /home/app

# Config location: ~/.config/plexamp-tui/config.json
VOLUME ["/home/app/.config/plexamp-tui"]

COPY --from=builder /out/plexamp-tui /usr/local/bin/plexamp-tui
COPY --from=builder /out/LICENSE /usr/share/licenses/plexamp-tui/LICENSE
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ARG UPSTREAM_REF
ENV PUID=99 \
    PGID=100 \
    UMASK=002
LABEL org.opencontainers.image.title="plexamp-tui" \
      org.opencontainers.image.description="Terminal controller for Plexamp headless" \
      org.opencontainers.image.source="https://github.com/spiercey/plexamp-tui" \
      org.opencontainers.image.version="${UPSTREAM_REF}" \
      org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
