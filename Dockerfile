# syntax=docker/dockerfile:1.7

# openclaw-honcho plugin as an OCI content artifact.
# Consumed by OpenClaw via a Kubernetes initContainer that runs `cp -r /plugin/. /dest/`
# then mounts /dest into the openclaw container's plugins.load.paths.

FROM node:22-alpine AS build
WORKDIR /build
RUN corepack enable && corepack prepare pnpm@9.15.9 --activate
COPY package.json pnpm-lock.yaml .npmrc ./
# --ignore-scripts skips the postinstall (`node install.js`) which requires
# install.js — not copied yet at this layer. install.js is a print-only
# no-op meant for runtime plugin install, not build. Ignoring it here keeps
# the deps-install layer cache-friendly (invalidates only on lockfile changes).
RUN pnpm install --frozen-lockfile --ignore-scripts
COPY . .
RUN pnpm build && pnpm prune --prod --ignore-scripts

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
