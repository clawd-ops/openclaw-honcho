# syntax=docker/dockerfile:1.7

# openclaw-honcho plugin as an OCI content artifact.
# Consumed by OpenClaw via a Kubernetes initContainer that runs `cp -r /plugin/. /dest/`
# then mounts /dest into the openclaw container's plugins.load.paths.

FROM node:22-alpine AS build
WORKDIR /build
RUN corepack enable && corepack prepare pnpm@9.15.9 --activate
COPY package.json pnpm-lock.yaml .npmrc ./
# node-linker=hoisted produces a flat node_modules tree (no .pnpm/ symlink
# store). OpenClaw's plugin safety scanner runs realpath() on every entry and
# does not follow pnpm's virtual-store symlinks — a pnpm-linked tree causes
# `openclaw plugins install` to fail on the first unresolvable link. Hoisted
# layout matches what npm publishes, which is what OpenClaw expects.
RUN pnpm install --frozen-lockfile --ignore-scripts --config.node-linker=hoisted
COPY . .
RUN pnpm build && pnpm prune --prod --ignore-scripts --config.node-linker=hoisted
# Fail the build if a pnpm virtual store snuck in — OpenClaw's plugin
# safety scanner cannot resolve those symlinks and would crashloop at
# runtime (see 2026-08-15 rollback of home-ops PR #944).
RUN if [ -d node_modules/.pnpm ]; then \
      echo "ERROR: node_modules/.pnpm exists — hoisted linker not applied"; \
      exit 1; \
    fi

FROM alpine:3.20
LABEL org.opencontainers.image.source="https://github.com/clawd-ops/openclaw-honcho"
LABEL org.opencontainers.image.description="Fork of @honcho-ai/openclaw-honcho packaged as OCI for OpenClaw local-path plugin loading"
LABEL org.opencontainers.image.licenses="MIT"
WORKDIR /plugin
COPY --from=build /build/package.json /build/openclaw.plugin.json /build/install.js ./
COPY --from=build /build/workspace_md ./workspace_md
COPY --from=build /build/dist ./dist
COPY --from=build /build/node_modules ./node_modules
# The initContainer overrides CMD with a cp into the shared volume mount.
CMD ["sh", "-c", "cp -a /plugin/. /dest/ && echo 'openclaw-honcho plugin copied to /dest'"]
