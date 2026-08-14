# clawd-ops/openclaw-honcho — Fork Notes

Fork of [`plastic-labs/openclaw-honcho`](https://github.com/plastic-labs/openclaw-honcho), maintained by Rob Landry for the OpenClaw + Honcho memory pipeline used at `honcho.landry.me`.

## Why the fork exists

Upstream PR/issue turnaround is measured in months. Several fixes and features we need have been open unmerged since March–May 2026:

- **#77 — fix: read sender ids from OpenClaw runtime context** (open 4+ months) — directly fixes the "everything attributes to `owner`" bug we're seeing on OpenClaw ≥2026.7.x.
- **#92** — related sender-attribution fix.
- **#82 / #83** — memory hygiene + capture dedupe controls.
- **#95** — explicit `honcho_remember` tool.
- **#103** — channel delta capture fix.

Rather than run patched builds locally, we fork, cherry-pick the fixes we vet, ship them via our own OCI pipeline, and re-open the same PRs upstream so plastic-labs can eventually merge them.

## Distribution

Fork is **not** published to npm. Built plugin ships as an OCI artifact to `ghcr.io/clawd-ops/openclaw-honcho:{sha,latest}` on every push to `main`.

Consumer: `roblandry/home-ops` OpenClaw HelmRelease pulls the OCI image in an initContainer, extracts to an emptyDir volume, and mounts it into the OpenClaw container's `plugins.load.paths`.

## Branches

- `main` — our tracking branch. Rebased against upstream `main` periodically.
- `upstream-pr-N` — historical mirror of every upstream PR's HEAD as of fork creation (2026-08-14). One-shot snapshot; not live-updated.
- `clawd-ops/*` — our own feature/fix branches, PR'd against fork `main`.

## Cherry-picking upstream PRs

Upstream PR branches (`upstream-pr-*`) are multi-commit — the branch tip alone
is not the full PR. Pick the whole range from where the PR forked off `main`:

```
git checkout main
git checkout -b clawd-ops/adopt-upstream-pr-77
git cherry-pick main..upstream-pr-77
# resolve conflicts if any
# review, codex-review, then merge to main
```

If you'd rather preserve the PR as a single merge commit (keeps individual
commits intact and easier to revert atomically):

```
git checkout -b clawd-ops/adopt-upstream-pr-77
git merge --no-ff upstream-pr-77
```

For every adopted PR, keep an `Upstream: plastic-labs/openclaw-honcho#N` trailer
in the merge/commit message so we can re-align if upstream merges a different
form of the same fix.

## Renovate

Home-ops Renovate watches `ghcr.io/clawd-ops/openclaw-honcho` for image tag bumps. We do NOT track upstream `plastic-labs/openclaw-honcho` npm version — the fork's OCI tag is authoritative for what runs.
