#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/.env"

remove_rule() {
    chain="$1"
    shift

    while sudo iptables -C "$chain" "$@" >/dev/null 2>&1; do
        sudo iptables -D "$chain" "$@"
    done
}

show_rules() {
    echo
    echo "DOCKER-USER:"
    sudo iptables -L DOCKER-USER -n -v --line-numbers
    echo
    echo "INPUT rules for $NETWORK_ISOLATED_SUBNET:"
    sudo iptables -L INPUT -n -v --line-numbers | grep -E "num|$NETWORK_ISOLATED_SUBNET" || true
}

# Remove host-local traffic rules.
remove_rule INPUT -s "$NETWORK_ISOLATED_SUBNET" -j DROP
remove_rule INPUT -s "$NETWORK_ISOLATED_SUBNET" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Remove forwarded traffic rules.
remove_rule DOCKER-USER -s "$NETWORK_ISOLATED_SUBNET" -j DROP
remove_rule DOCKER-USER -s "$NETWORK_ISOLATED_SUBNET" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo "Removed Docker network isolation for $NETWORK_ISOLATED_SUBNET"
show_rules
