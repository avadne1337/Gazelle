# Gazelle — Docker Compose deployment

Running on `claude@192.168.1.111` (Debian 13, arm64) under `/home/claude/gazelle`.

## Access
- Site: **http://192.168.1.111/**
- The **first account you register** (http://192.168.1.111/register.php) becomes **SysOp**.
  Open registration is on; you must solve the on-page captcha.

## Services (docker-compose.yml)
| Service    | Image                         | Role                                    |
|------------|-------------------------------|-----------------------------------------|
| nginx      | nginx:stable-alpine           | Web server, port 80                     |
| php        | built from docker/php         | PHP 7.4-fpm + gd, mysqli, mbstring, bcmath, sockets, zip, **mcrypt**, **memcache** |
| db         | mariadb:10.11                 | MySQL-compatible DB (strict mode off)   |
| memcached  | memcached:1.6-alpine          | Cache (TCP 11211, capped at 64 MB)      |
| sphinx     | manticoresearch/manticore     | Optional search backend (profile `search`) |

### Why these choices
- **PHP 7.4** (not 5.x): newest arm64 PHP image whose core still works with this
  codebase. `mcrypt` and the old `memcache` extension are added via PECL; `each()`
  and other deprecations are silenced in `docker/php/zz-gazelle.ini`.
- **MariaDB** instead of MySQL 5.7: MySQL 5.7 has no arm64 image.
- `classes/config.php` is generated (gitignored) with container hostnames
  (`db`, `memcached`, `sphinx`) and random keys/passwords.

## Managing it
```bash
cd /home/claude/gazelle
docker compose ps                 # status
docker compose logs -f php        # tail logs
docker compose restart            # restart all
docker compose down               # stop (DB data persists in the db_data volume)
docker compose up -d              # start
docker compose up -d --build php  # rebuild PHP image after a Dockerfile change
```
Containers use `restart: unless-stopped`, so they come back after a reboot.

## Security review / hardening applied
Audited the codebase for injection, dangerous sinks and auth weaknesses. The
SQL-injection surface is actually guarded (`is_number()` / `db_string()` / int
casts / permission checks), and the risky sinks (`shell_exec`, `eval`) are in
SysOp-only dev tools or internal helpers. Changes made:

- **Constant-time password check** — `Users::check_password()` compared hashes
  with `==`; switched to `hash_equals()` (`classes/users.class.php`). Removes a
  timing side-channel. Logic is otherwise identical.
- **bcrypt cost 07 → 10** (`CRYPT_HASH_PREFIX` in `classes/config.php`). Only
  affects newly created/changed passwords; existing hashes embed their own cost
  and still verify (tested).
- **Cookie/PHP hardening** (`docker/php/zz-gazelle.ini`): `session.cookie_httponly`,
  `session.cookie_samesite=Lax`, `session.use_strict_mode`, `html_errors=Off`,
  `display_errors=Off`, `expose_php=Off`. (The app's own auth cookie already sets
  HttpOnly.)
- **nginx** (`docker/nginx/default.conf`): `server_tokens off` and
  `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` headers;
  `gazelle.sql`, `docs/`, `docker/` and `classes/*.php|*.template` return 403.

- **Authenticated session cookie** (`classes/encrypt.class.php`): the `CRYPT`
  class now does Encrypt-then-MAC — an HMAC-SHA256 (key derived from `ENCKEY`) is
  verified in constant time *before* the CBC ciphertext is decrypted. This closes
  off tampering/forgery and ciphertext-manipulation against the login cookie.
  Tested end-to-end (login → session → authenticated page) and for tamper/legacy
  rejection. **Effect:** pre-existing login cookies are invalidated, so everyone
  must log in once more after this deploy.
- **PHP object-injection hardening**: all 32 `unserialize()` calls on DB/user
  data now pass `['allowed_classes' => false]`. Every serialized column holds an
  array (poll answers, Paranoia, SiteOptions, CustomPermissions, PushOptions,
  torrent dicts), so this changes no behaviour while blocking object injection.

> **Deploy note:** `default.conf` and the `.ini` are *single-file* bind mounts —
> Docker pins them by inode, so after editing them you must
> `docker compose restart nginx` / rebuild php, not just reload. The app code is
> a *directory* mount (`.:/var/www/gazelle`), so `.php` edits go live immediately.

## Not yet set up (follow-ups)
- **Search**: `browse`/search pages use Sphinx/Manticore. Start it with
  `docker compose --profile search up -d`, but the `torrents` index still needs to
  be built from the DB — `sphinx.conf` must be translated to Manticore syntax first.
- **Tracker (Ocelot)**: the C++ announce daemon isn't deployed, so torrents won't
  announce. The website itself is fully functional without it.
- **Cron jobs**: `schedule.php`, `peerupdate.php` and the Sphinx indexer (see
  `docs/INSTALL.txt`) are not scheduled.
- **TLS**: HTTP only. Put a reverse proxy / certs in front if you need HTTPS.
