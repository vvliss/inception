#!/bin/bash

MYSQL_HOST="${MYSQL_HOST}"

while ! mysqladmin ping -h "$MYSQL_HOST" -u "$MYSQL_USER" --password="$MYSQL_PASSWORD" --connect-timeout=2 --silent; do
    echo "Database not responding"
    sleep 1
done

#is wp alive
if [ ! -f /var/www/html/wp-config.php ];
then
    echo "WordPress doesn't exist"
    
#download wp
    wp core download \
        --allow-root \
        --path=/var/www/html

    wp config create \
        --allow-root \
        --path=/var/www/html \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="${MYSQLHOST}:${MYSQLPORT}"
    
    wp core install \
        --allow-root \
        --path=/var/www/html \
        --url="${DOMAIN_NAME}" \
        --title="inception" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email
    
    wp user create \
        --allow-root \
        --path=/var/www/html \
        "${WP_USER}" \
        --user_email="${WP_USER_EMAIL}" \
        --role=editor \
        --user_pass="${WP_USER_PASSWORD}"
fi

exec "$@"