# Developer Documentation

This document explains how to set up, build, run and maintain the Inception project from a developer's point of view.

## 1. Setting Up the Environment from Scratch

### Prerequisites

* A Linux virtual machine (Debian/Ubuntu recommended).
* `docker` and the `docker compose` plugin.
* `make` and `git`.
* Your user must be allowed to run Docker (member of the `docker` group, or use `sudo`).

Verify:

```sh
docker --version
docker compose version
make --version
```

### Domain name

Add the domain to `/etc/hosts`:

```
127.0.0.1   wilisson.42.fr
```

### Get the project

```sh
git clone <repository-url> ~/inception
cd ~/inception
```

### Project layout

```
inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/                     # passwords (ignored by Git)
└── srcs/
    ├── docker-compose.yml
    ├── .env                     # non-sensitive configuration (ignored by Git)
    └── requirements/
        ├── nginx/
        ├── wordpress/
        └── mariadb/
```

### Configuration files

**`srcs/.env`** — non-sensitive variables, for example:

```
DOMAIN_NAME=wilisson.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
WP_ADMIN_USER=<admin login>
WP_ADMIN_EMAIL=<admin email>
WP_USER=<second user login>
WP_USER_EMAIL=<second user email>
```

**`secrets/`** — one file per password, for example:

```
secrets/db_root_password.txt
secrets/db_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

Both are excluded from Git (`.gitignore`). The WordPress administrator username must **not** contain `admin` / `administrator` (subject requirement).

### Host data directories

The named volumes store their data in `/home/wilisson/data/`:

```sh
mkdir -p /home/wilisson/data/wordpress /home/wilisson/data/mariadb
```

(The `Makefile` normally creates them automatically.)

## 2. Building and Launching the Project

### Using the Makefile

| Command | Action |
| :--- | :--- |
| `make` | Create the data directories, build the images and start the containers (`docker compose up -d --build`). |
| `make down` | Stop and remove the containers (`docker compose down`). Volumes are kept. |
| `make clean` | Stop the containers and remove images and the network. |
| `make fclean` | `clean` + remove volumes and the data in `/home/wilisson/data/`. |
| `make re` | `fclean` followed by `make`. |

### Using Docker Compose directly

```sh
docker compose -f srcs/docker-compose.yml up -d --build
docker compose -f srcs/docker-compose.yml down
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs -f <service>
```

### Architecture overview

```
 Browser ──HTTPS :443──▶ [ nginx ] ──FastCGI :9000──▶ [ wordpress / php-fpm ] ──:3306──▶ [ mariadb ]
                                   (internal Docker network "inception")
```

* Only port **443** is published on the host.
* Containers communicate through the Docker network using service names (`wordpress`, `mariadb`).
* Each service is built from its own `Dockerfile` in `srcs/requirements/<service>/`.

## 3. Managing Containers and Volumes

### Containers

```sh
docker ps                          # running containers
docker ps -a                       # all containers
docker exec -it <container> sh     # open a shell inside a container (use bash if installed)
docker logs -f <container>         # follow logs
docker restart <container>         # restart a single container
docker compose -f srcs/docker-compose.yml build --no-cache <service>   # rebuild one image
```

### Volumes and network

```sh
docker volume ls                   # list volumes
docker volume inspect <volume>     # details (check the mount location)
docker network ls                  # list networks
docker network inspect <network>   # connected containers
```

### Useful checks

```sh
# Is the database reachable and are the tables there?
docker exec -it mariadb mariadb -u<db_user> -p

# Are the PHP-FPM and Nginx configurations valid?
docker exec nginx nginx -t
docker exec wordpress php-fpm -t        # binary name may include the version, e.g. php-fpm8.2

# Which TLS version does the server accept?
openssl s_client -connect wilisson.42.fr:443 -tls1_2
openssl s_client -connect wilisson.42.fr:443 -tls1_1   # must FAIL
```

## 4. Where the Data Is Stored and How It Persists

| Data | Volume | Location on the host | Location in the container |
| :--- | :--- | :--- | :--- |
| WordPress files (core, themes, plugins, uploads) | `wordpress_data` | `/home/wilisson/data/wordpress` | `/var/www/html` |
| Database files | `mariadb_data` | `/home/wilisson/data/mariadb` | `/var/lib/mysql` |

Persistence rules:

* `make down` / `docker compose down` removes containers but **keeps** the volumes — the data survives.
* Rebuilding images (`make re` without cleaning the data directories) keeps the data as long as the host directories are not deleted.
* `make fclean` deletes the data in `/home/wilisson/data/` — the next `make` creates a fresh WordPress and an empty database.
* Initialization scripts (database creation, WordPress installation) run only when the data directory is empty, so restarting never overwrites existing content.

### Backup (simple approach)

```sh
sudo tar czf inception-backup.tar.gz /home/wilisson/data
```

## 5. Common Issues and Debugging

| Symptom | Likely cause / fix |
| :--- | :--- |
| `make` fails with permission errors | The user is not in the `docker` group, or the data directories are owned by `root`. Check ownership of `/home/wilisson/data`. |
| `wilisson.42.fr` does not resolve | Missing entry in `/etc/hosts`. |
| Port 443 already in use | Another service is using it (`sudo ss -tlnp | grep 443`). Stop it. |
| WordPress shows "Error establishing a database connection" | MariaDB not ready yet, or credentials in `.env` / `secrets/` do not match the already-initialized database. Check `docker logs mariadb`; after changing credentials run `make fclean` and `make`. |
| 502 Bad Gateway | PHP-FPM is not running or not listening on the expected port. Check `docker logs wordpress` and the `fastcgi_pass` directive in the Nginx config. |
| Container restarts in a loop | The main process exits. Read the logs; make sure services run in the foreground (e.g. `nginx -g "daemon off;"`, `php-fpm -F`, `mysqld_safe`/`mariadbd`). |
| Changes in a `Dockerfile` are not applied | Rebuild without cache: `docker compose build --no-cache`. |

## 6. Notes on Subject Compliance

* No ready-made service images — only the base Debian/Alpine image is pulled.
* Nginx accepts **only TLSv1.2 / TLSv1.3** on port 443.
* No `network: host`, `links` or `--link`; a custom network is declared.
* No infinite-loop hacks (`tail -f`, `sleep infinity`, `while true`) as the container's main command.
* No passwords inside `Dockerfile`s; secrets and `.env` are used, and are not committed to Git.
* The `latest` tag is not used.