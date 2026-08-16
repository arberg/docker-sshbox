#!/bin/sh
set -eu

# Down removes the container and its project network. --rmi local also removes
# the image built by this project; persistent bind-mounted data is preserved.
docker compose down --rmi local
