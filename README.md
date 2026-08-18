# baikal-alpine

[![Docker Image CI](https://github.com/justadri/baikal-alpine/actions/workflows/docker-image.yml/badge.svg)](https://github.com/justadri/baikal-alpine/actions/workflows/docker-image.yml)
[![GHCR](https://img.shields.io/badge/ghcr.io-justadri%2Fbaikal--alpine-blue?logo=github)](https://github.com/justadri/baikal-alpine/pkgs/container/baikal-alpine)
[![Docker Hub](https://img.shields.io/docker/v/justadri/baikal-alpine?sort=semver&logo=docker&label=docker%20hub)](https://hub.docker.com/r/justadri/baikal-alpine)
[![Baikal](https://img.shields.io/badge/baikal-0.12.1-informational)](https://github.com/sabre-io/Baikal/releases/tag/0.12.1)

A single-container image for [Baikal](https://github.com/sabre-io/Baikal)
(CalDAV/CardDAV server), built on `php:8.4-fpm-alpine` + nginx, supervised
by [s6-overlay](https://github.com/just-containers/s6-overlay).

- Baikal version pinned via `BAIKAL_VERSION` build arg (default: 0.12.1)
- PHP extensions: pdo_sqlite, sqlite3, pdo_mysql, mysqli, pdo_pgsql, pgsql,
  dom, simplexml, xml, curl, mbstring, ctype, iconv, zip, opcache
- Mail via msmtp (configurable through env vars, see below)
- nginx + php-fpm both run as the `nginx` user

## Why this image

Baikal's own release doesn't ship a Docker image, so most people end up at
[ckulka/baikal-docker](https://github.com/ckulka/baikal-docker) — a solid,
long-running project this one is directly inspired by, and credited below.
A few things are different here:

- **PHP 8.4** on Alpine, rather than the Debian base + older PHP most
  existing Baikal images use.
- **Real process supervision.** php-fpm and nginx run under
  [s6-overlay](https://github.com/just-containers/s6-overlay), so a crashed
  php-fpm actually gets restarted instead of leaving nginx silently serving
  502s until someone notices.
- **CVE-patched dependencies.** Baikal's release zip ships a frozen
  `vendor/` that can lag behind known fixes upstream (this image build
  step exists specifically because Docker Scout flagged exactly that —
  see `Dockerfile` for the `composer require` step and why it fetches the
  real `composer.json` first).
- **Multi-arch.** `linux/amd64` and `linux/arm64` from the same tag, built
  in CI on every push.
- **Auto-updates itself.** Dependabot bumps the base PHP image and GitHub
  Actions weekly; a separate daily check
  ([`update-pinned-versions.yml`](.github/workflows/update-pinned-versions.yml))
  watches Baikal's and s6-overlay's own releases directly (they're pulled
  in via pinned `ARG`s, not a `FROM`, so Dependabot can't see them on its
  own) and opens a PR bumping them. Either kind of PR auto-merges once
  lint/build/smoke-test pass, which publishes a new image — so a new
  Baikal release shows up here without anyone needing to remember to
  update this repo.
- **Published to both [GHCR](https://github.com/justadri/baikal-alpine/pkgs/container/baikal-alpine)
  and [Docker Hub](https://hub.docker.com/r/justadri/baikal-alpine)** — pull
  from whichever you'd rather depend on; if Docker Hub's pull rate limits
  ever bite, GHCR has none for public images.

None of that makes it strictly *better* — ckulka's image is more mature and
has broader real-world mileage. This one's a from-scratch build for
anyone who'd rather have the above tradeoffs.

## Run
Copy compose.yml to the directory of your choice and edit as needed. Then, from
that directory:

```
docker compose up -d
```

Then open http://localhost:8080/admin/ to run the install wizard.

## Persistent data

Two named volumes hold everything that needs to survive:

- `/var/www/baikal/config` — baikal.yaml, generated after install
- `/var/www/baikal/Specific` — the SQLite db (if you use that backend) and
  any DAV auth backend, ACL Rules, etc.

## Mail configuration

Set one of:

- Discrete vars: `SMTP_HOST`, `SMTP_PORT` (default 587), `SMTP_USER`,
  `SMTP_PASS`, `SMTP_FROM`, `SMTP_TLS` (set to `off` to disable STARTTLS)
- Or `MSMTPRC` — full msmtp config file contents, if you need something
  the discrete vars don't cover.

See `docker/cont-init.d/20-msmtp.sh`.

## Database backend

Defaults to SQLite (zero config, stored in `/var/www/baikal/Specific/db`).
For MySQL/Postgres, uncomment the `db` service in `compose.yml` (or
point at an existing server) and select it in the Baikal install wizard —
the container already has both driver sets installed.

## Image tags

Published to both `ghcr.io/justadri/baikal-alpine` and `justadri/baikal-alpine`

| Tag | Meaning |
| --- | --- |
| `latest` | The current `main` |
| `x.y.z` (e.g. `0.12.1`) | Whatever `ARG BAIKAL_VERSION` in the Dockerfile currently is — moves with `main` |
| `<short-sha>` | Pinned to that exact commit, for rollback/debugging |

`latest` and the version tag always point at the same image.

A git tag matching `BAIKAL_VERSION` (e.g. `git tag 0.12.1 && git push origin
0.12.1`) is optional — it doesn't change what's published (that already
happens on the `main` push), it just marks the point in history as a named
release. Pair it with `gh release create 0.12.1 --generate-notes` for
changelog notes on GitHub.

## Notes

- `BAIKAL_SKIP_CHOWN=1` skips the ownership fix-up in cont-init.d, if
  you're managing permissions yourself on the mounted volumes.

## Credits

Baikal is the work of [Jérôme Schneider](https://github.com/jeromeschneider)
[fruux](https://fruux.com/), and the [Baikal](https://sabre.io/baikal) volunteers. 
Inspired by [ckulka](https://github.com/ckulka/baikal-docker) with substantial help
from [Claude](https://claude.ai)
