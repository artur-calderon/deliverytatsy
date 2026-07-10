#!/bin/sh
# Sobe a stack usando .env.docker para interpolacao do compose E para os containers.
set -e
cd "$(dirname "$0")"

if [ ! -f .env.docker ]; then
  echo "Crie .env.docker a partir do exemplo:"
  echo "  cp .env.docker.example .env.docker"
  exit 1
fi

# docker compose le .env por padrao para ${VARS} no YAML — espelha .env.docker
cp -f .env.docker .env

docker compose --env-file .env.docker up -d --build "$@"
