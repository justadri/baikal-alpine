# baikal-alpine

A single-container image for [Baikal](https://github.com/sabre-io/Baikal)
(CalDAV/CardDAV server), built on `php:8.4-fpm-alpine` + nginx, supervised
by [s6-overlay](https://github.com/just-containers/s6-overlay).

- Baikal version pinned via `BAIKAL_VERSION` build arg (default: 0.11.1)
- PHP extensions: pdo_sqlite, sqlite3, pdo_mysql, mysqli, pdo_pgsql, pgsql,
  dom, simplexml, xml, curl, mbstring, ctype, iconv, zip, opcache
- Mail via msmtp (configurable through env vars, see below)
- nginx + php-fpm both run as the `nginx` user

## Build & run

```
docker compose up --build -d
```

Then open http://localhost:8080/admin/ to run the install wizard.

## Persistent data

Two named volumes hold everything that needs to survive a rebuild:

- `/var/www/baikal/config` — baikal.yaml, generated after install
- `/var/www/baikal/Specific` — the SQLite db (if you use that backend) and
  any DAV auth backend, ACL Rules, etc.

Everything else in `/var/www/baikal` comes from the image and is safe to
throw away/rebuild.

## Mail configuration

Set one of:

- Discrete vars: `SMTP_HOST`, `SMTP_PORT` (default 587), `SMTP_USER`,
  `SMTP_PASS`, `SMTP_FROM`, `SMTP_TLS` (set to `off` to disable STARTTLS)
- Or `MSMTPRC` — full msmtp config file contents, if you need something
  the discrete vars don't cover.

See `docker/cont-init.d/20-msmtp.sh`.

## Database backend

Defaults to SQLite (zero config, stored in `/var/www/baikal/Specific/db`).
For MySQL/Postgres, uncomment the `db` service in `docker-compose.yml` (or
point at an existing server) and select it in the Baikal install wizard —
the container already has both driver sets installed.

## Notes

- `BAIKAL_SKIP_CHOWN=1` skips the ownership fix-up in cont-init.d, if
  you're managing permissions yourself on the mounted volumes.
- Rebuild to bump the Baikal version: `docker compose build --build-arg
  BAIKAL_VERSION=x.y.z`.


Made possible by the work of [sabre.io](https://github.com/sabre-io/Baikal) 
and [ckulka](https://github.com/ckulka/baikal-docker) with substantial help
from [Claude](https://claude.ai)
