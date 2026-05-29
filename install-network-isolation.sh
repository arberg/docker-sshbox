#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/.env"

ensure_rule() {
    chain="$1"
    position="$2"
    shift 2

    if ! sudo iptables -C "$chain" "$@" >/dev/null 2>&1; then
        sudo iptables -I "$chain" "$position" "$@"
    fi
}

show_rules() {
    echo
    echo "DOCKER-USER:"
    sudo iptables -L DOCKER-USER -n -v --line-numbers
    echo
    echo "INPUT rules for $NETWORK_ISOLATED_SUBNET:"
    sudo iptables -L INPUT -n -v --line-numbers | grep -E "num|$NETWORK_ISOLATED_SUBNET" || true
}

# Blocks NEW outbound connections from the isolated Docker subnet to:
#   - LAN / Internet via DOCKER-USER
#   - the Docker host itself via INPUT
#
# Inbound traffic via published host ports still works because reply packets
# from the container are ESTABLISHED/RELATED and are accepted before the drops.

# Make sure Docker's user chain exists.
sudo iptables -N DOCKER-USER 2>/dev/null || true

# ---- Forwarded traffic: container -> LAN / Internet ----
# Allow replies for already-established connections, including sessions
# initiated from outside into published ports.
ensure_rule DOCKER-USER 1 -s "$NETWORK_ISOLATED_SUBNET" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Block all new forwarded traffic originating from the isolated subnet.
ensure_rule DOCKER-USER 2 -s "$NETWORK_ISOLATED_SUBNET" -j DROP

# ---- Host-local traffic: container -> Docker host ----
# Allow replies from the container to host-initiated connections, for example:
#   host -> 127.0.0.1:<published-port> -> container:<service-port>
ensure_rule INPUT 1 -s "$NETWORK_ISOLATED_SUBNET" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Block new connections from the isolated subnet to services on the Docker host,
# for example:
#   container -> 10.0.0.2:80
#   container -> 172.16.250.1:80
ensure_rule INPUT 2 -s "$NETWORK_ISOLATED_SUBNET" -j DROP

echo "Installed Docker network isolation for $NETWORK_ISOLATED_SUBNET"
show_rules
