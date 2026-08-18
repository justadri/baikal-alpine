# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Dockerfile that packages [Baikal](https://github.com/sabre-io/Baikal) (CalDAV/CardDAV
server) into a single container: `php:8.4-fpm-alpine` + nginx + msmtp, supervised by
s6-overlay. There is no application source code here — Baikal itself is downloaded as a
release zip during the image build (see the Dockerfile's `wget` of
`sabre-io/Baikal/releases/download/${BAIKAL_VERSION}/...`). This repo only contains the
container packaging: the Dockerfile and everything under `docker/`.

## Commands

Build the image locally:
```
docker build -t baikal-alpine .
```

Run it (uses `compose.yml`, which is also the file end users copy to deploy):
```
docker compose up -d
```
Then `http://localhost:8080/admin/` runs the install wizard.

Lint the Dockerfile (what CI runs, via `hadolint/hadolint-action`):
```
hadolint Dockerfile --ignore DL3018
```
(DL3018 — apk add without pinned version — is intentionally ignored; see the CI workflow
comment for why.)

There is no test suite. CI's "smoke-test" job is the closest thing: it runs the built
image and polls `/admin/` for an HTTP 200. To reproduce locally after a build:
```
docker run -d --name baikal-smoke -p 8080:80 baikal-alpine
curl -sL -o /dev/null -w '%{http_code}\n' http://localhost:8080/admin/
docker rm -f baikal-smoke
```

## Architecture

- **Dockerfile** — single-stage build on `php:8.4-fpm-alpine`. Order of concern:
  1. apt/apk system packages + PHP extensions (via `mlocati/docker-php-extension-installer`)
  2. s6-overlay download/install (process supervision)
  3. Baikal release zip download → unpacked to `/var/www/baikal`
  4. **Dependency patch step**: fetches the real `composer.json` for the pinned Baikal
     tag from GitHub, then runs `composer require` to force `twig/twig` and
     `symfony/yaml` past versions with known CVEs. This exists because Baikal's release
     zip ships a frozen `vendor/` that can lag behind upstream fixes — don't remove it
     without checking whether the CVEs it addresses are still relevant to the pinned
     `BAIKAL_VERSION`.
  5. Copies in the `docker/` config files described below.
  - Everything under `/var/www/baikal` is chowned to `nginx:nginx` at build time; both
    nginx and php-fpm run as that user at runtime (not root).
  - `BAIKAL_VERSION`, `S6_OVERLAY_VERSION`, `TWIG_VERSION`, `SYMFONY_YAML_VERSION` are all
    build `ARG`s at the top of the Dockerfile — bump these, not anything downstream, when
    updating pinned versions by hand.

- **docker/services.d/** — s6-overlay long-running services (`nginx`, `php-fpm`), each a
  `run` script. `nginx`'s `run` script polls for `/run/php-fpm.sock` before starting,
  since legacy s6 `services.d` has no built-in dependency ordering between services.

- **docker/cont-init.d/** — s6-overlay one-shot init scripts, run once before services
  start:
  - `10-permissions.sh` — chowns only the two VOLUME-mounted paths
    (`/var/www/baikal/Specific`, `/var/www/baikal/config`) to `nginx:nginx` on every
    container start, since mounted volumes lose the build-time ownership. Skippable via
    `BAIKAL_SKIP_CHOWN=1`.
  - `20-msmtp.sh` — templates `/etc/msmtprc` from either a full `MSMTPRC` env var or the
    discrete `SMTP_*` vars (see README's "Mail configuration" section for the full var
    list).

- **docker/nginx.conf**, **docker/php-fpm-pool.conf**, **docker/php-baikal.ini** — nginx
  vhost, the php-fpm `www` pool override (runs as `nginx` user, listens on a unix
  socket at `/run/php-fpm.sock` rather than TCP), and PHP ini overrides (upload limits,
  opcache, routing `mail()` through msmtp via `sendmail_path`).

## CI/CD (`.github/workflows/`)

- **docker-image.yml** — the main pipeline, gated in sequence: `lint` (hadolint) →
  `build` (multi-arch `linux/amd64,linux/arm64` via buildx, pushed to both GHCR and
  Docker Hub on `push` events) → `smoke-test` (pulls the built image, curls `/admin/`
  until it 200s) → `release` (auto-creates a `vX.Y.Z` GitHub release from the Dockerfile's
  pinned `BAIKAL_VERSION` once it reaches `main`) → `dockerhub-description` (syncs
  README.md to Docker Hub). A push to a `*.*.*` git tag overrides `BAIKAL_VERSION` for
  that build only, rather than relying on the Dockerfile default.
- **update-pinned-versions.yml** — runs daily, checks the latest upstream Baikal and
  s6-overlay releases via the GitHub API, and opens an auto-mergeable PR bumping the
  `ARG` pins in the Dockerfile when either is behind. This exists because those two are
  pulled in via `wget` against a pinned `ARG`, not a `FROM`, so Dependabot's docker
  ecosystem check (`.github/dependabot.yml`) can't see them — Dependabot only covers the
  `php` base image and GitHub Actions versions.
- Both PR-opening workflows (`update-pinned-versions.yml` and Dependabot) auto-merge once
  lint/build/smoke-test pass, using a `RELEASE_PAT` (not the default `GITHUB_TOKEN`) so
  the resulting push still triggers `docker-image.yml`'s checks — pushes made with the
  default token don't trigger other workflows, which would otherwise permanently block
  auto-merge from ever seeing a passing check.

## Editing conventions specific to this repo

- Keep version pins as `ARG`s at the top of the Dockerfile — CI's `lint`/`build` jobs and
  `update-pinned-versions.yml` both `grep`/`sed` those exact lines
  (`^ARG BAIKAL_VERSION=`, `^ARG S6_OVERLAY_VERSION=`), so don't reformat or relocate them.
  If you need a comment on why the CVE-patch `composer require` step targets specific
  `twig/twig`/`symfony/yaml` versions, put it near those `ARG`s, not inline in the `RUN`.
- README.md is synced verbatim to the Docker Hub repository description by CI on every
  push to `main` — keep it accurate as user-facing documentation, not just internal notes.
