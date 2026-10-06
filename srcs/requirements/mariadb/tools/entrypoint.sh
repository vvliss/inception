#!/bin/bash

set -e

SOCKET="/run/mysqld/mysqld.sock"

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

echo "starting temporary server"
mysqld_safe --skip-networking &
TEMP_SERVER_PID=$!

echo "waiting for socket"
while ! mysqladmin \
    --protocol=socket \
    --socket="$SOCKET" \
    --connect-timeout=2 \
    --silent \
    ping; do
    sleep 1
done

echo "creating db and user"
mysql \
    --protocol=socket \
    --socket="$SOCKET" \
    -u root <<-EOSQL
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%'
        IDENTIFIED BY '${MYSQL_PASSWORD}';
    ALTER USER '${MYSQL_USER}'@'%'
        IDENTIFIED BY '${MYSQL_PASSWORD}';
    GRANT ALL PRIVILEGES 
        ON \`${MYSQL_DATABASE}\`.*
        TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL

echo "stopping temporary server"
mysqladmin \
    --protocol=socket \
    --socket="$SOCKET" \
    -u root \
    shutdown

wait "$TEMP_SERVER_PID" 2>/dev/null || true

echo "starting MariaDB"
exec "$@"