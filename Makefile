NAME = inception

all: up

up:
	mkdir -p /home/wilisson/data/wordpress
	mkdir -p /home/wilisson/data/mariadb
	docker compose -f srcs/docker-compose.yml up -d --build

down:
	docker compose -f srcs/docker-compose.yml down

clean:
	docker compose -f srcs/docker-compose.yml down -v
	docker system prune -af

re: clean all

.PHONY: all up down clean re