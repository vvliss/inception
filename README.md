*This project has been created as part of the 42 curriculum by wilisson.*

# Inception

## Description

**Inception** is a system administration project from the 42 curriculum. Its goal is to build a small, self-contained web infrastructure using **Docker** and **Docker Compose**, running inside a virtual machine. Every service is built from a custom `Dockerfile` (no ready-made images from Docker Hub, except the base Debian/Alpine image).

The infrastructure is composed of three services, each running in its own dedicated container:

| Service | Role |
| :--- | :--- |
| **Nginx** | The only entry point. Serves HTTPS on port 443 only (TLSv1.2 / TLSv1.3) and forwards PHP requests to WordPress (PHP-FPM). |
| **WordPress + PHP-FPM** | The CMS powering the website and its administration panel. |
| **MariaDB** | The database storing all WordPress content. |

Supporting elements:

* A dedicated **Docker network** connecting the containers.
* Two **named volumes** persisting data on the host in `/home/wilisson/data/`:
  * `wordpress_data` — website files,
  * `mariadb_data` — database files.
* Containers restart automatically in case of a crash.
* The domain `wilisson.42.fr` points to the local IP address of the virtual machine.

### Project structure and sources included

```
inception/
├── .gitignore               # excludes srcs/.env from Git
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── .env                 # all configuration and credentials (not committed)
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/         # Dockerfile, conf/, tools/
        ├── nginx/           # Dockerfile, conf/, tools/
        └── wordpress/
            ├── Dockerfile
            ├── conf/
            │   └── www.conf # PHP-FPM pool configuration
            └── tools/       # setup script(s)
```

* The `Makefile` builds and manages the whole stack through `docker compose`.
* `docker-compose.yml` defines the services, the network, the volumes and loads the configuration from `.env`.
* Each directory in `requirements/` contains the `Dockerfile` of a single service, its configuration files (`conf/`) and setup scripts (`tools/`).
* `.gitignore` keeps the `srcs/.env` file (with credentials) out of the repository.

### Main design choices

* **One service per container** — each process is isolated, easier to debug, rebuild and replace.
* **Custom Dockerfiles** based on a pinned penultimate stable version of Debian/Alpine — full control over what is installed.
* **Nginx as the single entry point** — MariaDB and WordPress are not exposed to the host; only port 443 is published.
* **TLS only** — no plain HTTP; a self-signed certificate is generated for `wilisson.42.fr`.
* **Credentials kept out of images and Git** — all configuration and passwords are stored in the `.env` file, which is excluded from Git (`.gitignore`) and never hardcoded in `Dockerfile`s.
* **Persistent data** — database and website files survive container removal and rebuilds.
* **PID 1 handled properly** — services run in the foreground (no `tail -f`, `sleep infinity` or `while true` hacks).

### Virtual Machines vs Docker

| | Virtual Machine | Docker |
| :--- | :--- | :--- |
| **Isolation** | Full OS with its own kernel, isolated by a hypervisor. | Processes isolated through kernel namespaces and cgroups; the host kernel is shared. |
| **Size** | Gigabytes (whole OS). | Megabytes (only the app and its dependencies). |
| **Startup** | Minutes. | Seconds. |
| **Resources** | Heavy: dedicated RAM/CPU for the guest OS. | Light: close to native performance. |
| **Portability** | Disk images, heavier to move. | Images built from a `Dockerfile`, reproducible and easy to share. |
| **Best for** | Strong isolation, running different operating systems. | Packaging and deploying applications and microservices. |

In this project the VM provides the safe, isolated host environment, while Docker splits the application into lightweight, reproducible services.

### Secrets vs Environment Variables

| | Environment Variables | Docker Secrets |
| :--- | :--- | :--- |
| **Storage** | Part of the container configuration / process environment. | Files mounted read-only in `/run/secrets/` inside the container. |
| **Visibility** | Visible via `docker inspect`, `/proc`, logs and child processes. | Not exposed in the environment or in `docker inspect`. |
| **Use case** | Non-sensitive configuration (domain name, database name, usernames). | Passwords, API keys, certificates. |

In this project **all configuration and credentials are stored in the `.env` file** and passed to the containers as environment variables by Docker Compose. The file is excluded from Git and the values are never hardcoded in `Dockerfile`s. Docker secrets would be the safer choice for a production environment, but they are not required here, so a single `.env` file keeps the setup simple.

### Docker Network vs Host Network

| | Docker Network (bridge) | Host Network |
| :--- | :--- | :--- |
| **Isolation** | Containers get their own network namespace and private IPs. | Container shares the host's network stack directly. |
| **Name resolution** | Containers reach each other by service name (`mariadb`, `wordpress`). | No built-in service discovery. |
| **Exposure** | Only explicitly published ports are reachable. | Every port the app opens is open on the host. |
| **Security** | Much better — services can stay internal. | Weaker isolation. |

This project uses a custom **bridge network**, so that Nginx, WordPress and MariaDB talk to each other by name and only Nginx's port 443 is published. `network: host` and `links` are forbidden by the subject.

### Docker Volumes vs Bind Mounts

| | Docker Volumes | Bind Mounts |
| :--- | :--- | :--- |
| **Managed by** | Docker (stored in Docker's area, or at a defined location). | The user — maps an arbitrary host path into the container. |
| **Portability** | Independent of the host directory layout. | Depends on the host's directory structure and permissions. |
| **Management** | `docker volume ls/inspect/rm`, easy backups. | Plain filesystem tools. |
| **Typical use** | Persistent application data (databases). | Sharing source code or config during development. |

The subject requires **named volumes** for the two data stores; they are configured so that the data physically lives in `/home/wilisson/data/` on the host.

## Instructions

### Prerequisites

* A Linux virtual machine with `docker`, `docker compose` and `make` installed.
* The following line in `/etc/hosts` (replace with your VM's IP if needed):

  ```
  127.0.0.1   wilisson.42.fr
  ```

### Setup

1. Clone the repository:

   ```sh
   git clone <repository-url> ~/inception
   cd ~/inception
   ```

2. Create the configuration file `srcs/.env` (it is not stored in Git). It contains all variables: domain name, database name, usernames, e-mails and passwords (database root and user, WordPress administrator and user).

3. Build and start everything:

   ```sh
   make
   ```

4. Open `https://wilisson.42.fr` in a browser (accept the self-signed certificate warning).

### Useful commands

| Command | Action |
| :--- | :--- |
| `make` (or `make up`) | Create the data directories, build the images and start all containers in the background. |
| `make down` | Stop and remove the containers (data is kept). |
| `make clean` | Stop the containers and remove the Docker volumes, then run `docker system prune -af` (removes all unused images, containers and networks). Files in `/home/wilisson/data/` stay on the host. |
| `make re` | `clean` followed by a fresh `make` (full rebuild). |

More details:

* End users and administrators → see [`USER_DOC.md`](USER_DOC.md).
* Developers → see [`DEV_DOC.md`](DEV_DOC.md).

## Resources

### Documentation and references

* [Docker documentation](https://docs.docker.com/)
* [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
* [Docker Compose documentation](https://docs.docker.com/compose/)
* [Docker secrets in Compose](https://docs.docker.com/compose/how-tos/use-secrets/)
* [Docker networking overview](https://docs.docker.com/engine/network/)
* [Docker volumes and bind mounts](https://docs.docker.com/engine/storage/)
* [Nginx documentation](https://nginx.org/en/docs/) — including [ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
* [WordPress developer resources](https://developer.wordpress.org/) and [WP-CLI handbook](https://make.wordpress.org/cli/handbook/)
* [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
* [MariaDB Knowledge Base](https://mariadb.com/kb/en/documentation/)
* [Best practices for writing Dockerfiles](https://docs.docker.com/build/building/best-practices/)
* [PID 1 and signal handling in containers](https://docs.docker.com/engine/containers/multi-service_container/)

### Use of AI

In line with the 42 guidelines, AI was treated as a learning and productivity aid, not a replacement for understanding. It was used to reduce repetitive work and to explain concepts, while the design decisions, configuration and testing remain my own responsibility.

| Task | How AI was used |
| :--- | :--- |
| **Documentation** | Drafting and structuring `README.md`, `USER_DOC.md` and `DEV_DOC.md` according to the subject's requirements, including the comparison tables. |
| **Learning / explanations** | Clarifying concepts: VM vs Docker, secrets vs environment variables, Docker networks, volumes vs bind mounts, PID 1 in containers, TLS configuration in Nginx. |
| **Review** | Suggesting ideas for troubleshooting and checking configurations. |