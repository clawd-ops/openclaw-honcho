# syntax=docker/dockerfile:1.7

# openclaw-honcho plugin as an OCI content artifact.
# Consumed by OpenClaw via a Kubernetes initContainer that runs `cp -r /plugin/. /dest/`
# then mounts /dest into the openclaw container's plugins.load.paths.

FROM node:22-alpine AS build
WORKDIR /build
RUN corepack enable && corepack prepare pnpm@9.15.9 --activate
COPY package.json pnpm-lock.yaml .npmrc ./
# Build with the full pnpm-managed dev dep tree so the tsc build sees types.
# --ignore-scripts skips the postinstall (`node install.js`) which requires
# install.js — not copied yet at this layer.
RUN pnpm install --frozen-lockfile --ignore-scripts
COPY . .
RUN pnpm build

# Produce a FLAT, hoisted --prod node_modules for shipping.
# OpenClaw's plugin safety scanner (`openclaw plugins install <path>`) does
# `realpath` on every entry in node_modules and fails on pnpm's default
# virtual-store symlink layout (`node_modules/.pnpm/<pkg>@<ver>/node_modules/<pkg>`
# + relative symlinks). --node-linker=hoisted produces the flat layout npm
# publishes, which the scanner accepts. Install into /ship/node_modules so we
# can COPY only that in the final stage without dragging in the pnpm virtual
# store from /build/node_modules.
RUN mkdir -p /ship && cp package.json pnpm-lock.yaml .npmrc /ship/ && \
    cd /ship && \
    pnpm install --frozen-lockfile --prod --ignore-scripts --node-linker=hoisted && \
    rm -f package.json pnpm-lock.yaml .npmrc

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
CMD ["sh", "-c", "cp -R /plugin/. /dest/ && echo 'openclaw-honcho plugin copied to /dest'"]
