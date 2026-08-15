# syntax=docker/dockerfile:1.7

# openclaw-honcho plugin as an OCI content artifact.
# Consumed by OpenClaw via a Kubernetes initContainer that runs `cp -r /plugin/. /dest/`
# then mounts /dest into the openclaw container's plugins.load.paths.

FROM node:22-alpine AS build
WORKDIR /build
RUN corepack enable && corepack prepare pnpm@9.15.9 --activate
COPY package.json pnpm-lock.yaml .npmrc ./
RUN pnpm install --frozen-lockfile --ignore-scripts
COPY . .
RUN pnpm build

# Fresh production install into /ship with hoisted linker. Doing this in a
# separate directory (rather than `pnpm prune`) is the reliable way to get a
# flat, symlink-free node_modules tree that matches what npm publishes.
# OpenClaw's plugin safety scanner runs realpath() on every entry and does
# not follow pnpm's virtual-store symlinks — a pnpm-linked tree caused the
# 2026-08-15 rollback of home-ops PR #944.
WORKDIR /ship
COPY package.json pnpm-lock.yaml .npmrc ./
RUN pnpm install --frozen-lockfile --prod --ignore-scripts \
      --config.node-linker=hoisted

# Layout guard: fail the build if any dangling symlinks or realpath failures
# exist under node_modules. This is what the OpenClaw scanner actually cares
# about — not the presence of `.pnpm/lock.yaml` metadata, which hoisted
# installs keep.
RUN set -e; \
    if find node_modules -type l | grep -q .; then \
      echo "ERROR: symlinks found under node_modules — hoisted linker not applied"; \
      find node_modules -type l -print; \
      exit 1; \
    fi; \
    find node_modules -exec realpath {} + >/dev/null

FROM alpine:3.20
LABEL org.opencontainers.image.source="https://github.com/clawd-ops/openclaw-honcho"
LABEL org.opencontainers.image.description="Fork of @honcho-ai/openclaw-honcho packaged as OCI for OpenClaw local-path plugin loading"
LABEL org.opencontainers.image.licenses="MIT"
WORKDIR /plugin
COPY --from=build /build/package.json /build/openclaw.plugin.json /build/install.js ./
COPY --from=build /build/workspace_md ./workspace_md
COPY --from=build /build/dist ./dist
COPY --from=build /ship/node_modules ./node_modules
# The initContainer overrides CMD with a cp into the shared volume mount.
CMD ["sh", "-c", "cp -a /plugin/. /dest/ && echo 'openclaw-honcho plugin copied to /dest'"]
