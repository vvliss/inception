# User Documentation

This documentation is intended for end users and administrators who want to use the Inception infrastructure — start it, access the website, log in, and verify that everything is running correctly. No prior Docker knowledge is required.

## 1. What Services Are Provided?

The infrastructure is composed of three services running in separate containers:

| Service | Role | How you access it |
| :--- | :--- | :--- |
| **Nginx** | The web server. It is the only entry point. It handles HTTPS (secure connection) and forwards PHP requests to WordPress. | `https://wilisson.42.fr` |
| **WordPress** | The Content Management System (CMS). It powers the website and its administration panel. | Same URL as above |
| **MariaDB** | The database. It stores all website content: posts, pages, users, comments, and settings. | Internal only (not accessed directly) |

Two **named volumes** are used to persist data on the host machine:

* `wordpress_data` — stores the website files (themes, plugins, uploads).
* `mariadb_data` — stores the database files.

Both volumes are stored inside `/home/wilisson/data/` on the host.

## 2. Starting and Stopping the Project

All commands are run from the root of the repository (`~/inception`).

### Start the project

```sh
make
```

This builds the images (on the first run) and starts all three containers in the background.

### Stop the project

```sh
make down
```

This stops and removes the containers. **Your data is kept** (it lives in the volumes).

### Restart the project

```sh
make down
make
```

### Remove everything (including data)

```sh
make fclean
```

> ⚠️ **Warning:** this permanently deletes the website content and the database stored in `/home/wilisson/data/`.

## 3. Accessing the Website and the Administration Panel

### Prerequisite

The domain name must point to the machine running the project. Check that `/etc/hosts` contains:

```
127.0.0.1   wilisson.42.fr
```

### Website

Open in a browser:

```
https://wilisson.42.fr
```

The connection uses a **self-signed certificate**, so the browser will show a security warning. This is expected — choose *Advanced* → *Proceed to wilisson.42.fr*.

> Only HTTPS (port 443) is available. `http://` (port 80) does not work.

### Administration panel

```
https://wilisson.42.fr/wp-admin
```

Log in with the **administrator** account. From the panel you can create posts and pages, install themes and plugins, manage users and comments, and change the site settings.

## 4. Credentials — Where to Find and Manage Them

| What | Where it is stored |
| :--- | :--- |
| Non-sensitive settings (domain, database name, usernames) | `srcs/.env` |
| Passwords (database, WordPress administrator, WordPress user) | Files in the `secrets/` directory |

Notes:

* These files are **not** stored in Git — they exist only on the machine running the project.
* The WordPress administrator username and the passwords are defined in these files before the first start.
* To change a password after the first start, change it in the WordPress panel (*Users → Profile*). Editing the secret file alone does **not** update an already-initialized database. A full reset (`make fclean`, then `make`) re-initializes everything with the values from the files.
* Keep these files private and never share them.

## 5. Checking That Services Are Running Correctly

### Quick check — the website

Open `https://wilisson.42.fr`. If the WordPress site loads, the whole chain (Nginx → WordPress → MariaDB) is working.

### Check the containers

```sh
docker ps
```

You should see three containers (`nginx`, `wordpress`, `mariadb`) with the status **Up**.

### Check the logs

```sh
docker logs nginx
docker logs wordpress
docker logs mariadb
```

### Common problems

| Problem | What to do |
| :--- | :--- |
| Site does not open | Check that all three containers are **Up** (`docker ps`) and that `/etc/hosts` contains the `wilisson.42.fr` entry. |
| Browser warns about security | Expected (self-signed certificate) — proceed anyway. |
| "Error establishing a database connection" | MariaDB may still be starting — wait a few seconds and refresh. If it persists, check `docker logs mariadb`. |
| A container is not running | Run `make down` and then `make` again. |