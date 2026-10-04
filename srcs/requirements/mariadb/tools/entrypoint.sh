#!/bin/bash

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "initializing MariaDB..."

    mariadb-install-db --user=mysql --datadir=/var/lib/mysql

    mysqld_safe --skip-networking &

    while ! mysqladmin ping --silent --connect-timeout=2; do
        echo "waiting for mariadb..."
        sleep 1
    done

    
fi

exec "$@"