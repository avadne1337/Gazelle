# Gazelle — Dockerized & PHP 8 edition

[Gazelle](https://github.com/WhatCD/Gazelle) is the web framework behind private
BitTorrent music trackers (originally What.CD) — written in PHP, JavaScript and
MySQL. This repository packages the whole thing as a **one-command Docker Compose
stack** and ports the 2016-era codebase to **PHP 8.3**, so it runs on modern,
security-patched software (including the fix for the *php2shell* RCEs,
CVE-2026-109618/109619).

> Tested on arm64 (Raspberry Pi, Debian) — the full stack runs in ~350 MB RAM.

---

## What's inside

A self-contained stack, wired together on a private Compose network:

| Service     | Image / build            | Role                                                    |
|-------------|--------------------------|---------------------------------------------------------|
| **nginx**   | `nginx:stable-alpine`    | Web server + TLS (HTTP → HTTPS), security headers        |
| **php**     | `php:8.3-fpm` (custom)   | The Gazelle app — gd, mysqli, mbstring, bcmath, sockets, zip, memcached, OpenSSL |
| **db**      | `mariadb:10.11`          | Database (loads `gazelle.sql` on first boot)             |
| **memcached** | `memcached:1.6-alpine` | Object & page cache                                      |
| **ocelot**  | built from source        | The C++ BitTorrent tracker daemon (announce/scrape, :2710) |
| **sphinx**  | `manticoresearch/manticore` | Full-text search (SphinxQL), opt-in via the `search` profile |
| **cron**    | reuses the php image     | `schedule.php` + `peerupdate.php` every 15 min; search reindex loop |

## Quick start

```bash
cp .env.example .env            # fill in passwords + 32-char tracker/schedule keys
cp classes/config.template classes/config.php   # set SITE_URL/keys to match .env
docker compose up -d                       # core stack (site + tracker + cron)
docker compose --profile search up -d      # add full-text search (Manticore)
```

Then open **https://&lt;host&gt;/** (a self-signed cert, so expect a one-time browser
warning) and register — **the first account becomes SysOp**.

> `sphinx` is behind the `search` profile, so a plain `docker compose up/down`
> leaves it untouched. Start/stop it explicitly with `--profile search`.

## Configuration

- **`.env`** (gitignored) — DB passwords, `TRACKER_SECRET`/`TRACKER_REPORTKEY`,
  `SCHEDULE_KEY`. `.env.example` documents every key.
- **`classes/config.php`** (gitignored) — the app config: site URL, keys, and the
  container hostnames (`db`, `memcached`, `sphinx`, `ocelot`).
- **TLS** — `docker/nginx/gen-cert.sh` generates a self-signed cert into
  `docker/nginx/certs/` (also gitignored). Swap in a real cert for production.

## What changed vs. upstream

- **PHP 8.3 port** — removed `each()`/`create_function()`, replaced `mcrypt` with
  OpenSSL, swapped the dead `memcache` extension for `memcached`, and fixed the
  PHP-8 strictness fatals throughout.
- **Security hardening** — php2shell-patched PHP, constant-time password checks,
  authenticated (encrypt-then-HMAC) session cookies, `allowed_classes => false`
  on every `unserialize()` of DB data, hardened nginx/PHP, and secrets kept out
  of git.
- **Modern infra** — MariaDB instead of the unmaintained MySQL 5.7, Manticore in
  place of classic Sphinx, HTTPS, and in-stack cron.

Full operations guide — services, management commands, TLS, cron, and the
migration details — is in **[docker/DEPLOY.md](docker/DEPLOY.md)**.

## Credits

Built on [WhatCD/Gazelle](https://github.com/WhatCD/Gazelle) and
[WhatCD/Ocelot](https://github.com/WhatCD/Ocelot). Gazelle's original coding
standards and installation notes live in the project
[wiki](https://github.com/WhatCD/Gazelle/wiki) and under `docs/`.
