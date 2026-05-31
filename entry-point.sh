#!/bin/sh
set -e

USER_NAME="${USERNAME:-sshbox}"
HOME_DIR="${HOME_DIR:-/home/$USER_NAME}"
GROUP_NAME="users"

mkdir -p "$HOME_DIR"

# A bind-mounted home directory hides the files created by useradd -m during
# image build. If this looks like a fresh home directory, initialize it from
# Debian's default skeleton files.
if [ ! -f "$HOME_DIR/.profile" ] && [ ! -f "$HOME_DIR/.bashrc" ]; then
    cp -a /etc/skel/. "$HOME_DIR/"
    chown -R "$USER_NAME:$GROUP_NAME" "$HOME_DIR"
fi

# SSH StrictModes requires the home and .ssh paths not to be writable by group
# or others, and authorized_keys must be owned by the login user and not be too
# permissive. The key file itself is supplied by the mounted host directory.
chown "$USER_NAME:$GROUP_NAME" "$HOME_DIR"
chmod go-w "$HOME_DIR"

mkdir -p "$HOME_DIR/.ssh"
chown "$USER_NAME:$GROUP_NAME" "$HOME_DIR/.ssh"
chmod 700 "$HOME_DIR/.ssh"

if [ -f "$HOME_DIR/.ssh/authorized_keys" ]; then
    chown "$USER_NAME:$GROUP_NAME" "$HOME_DIR/.ssh/authorized_keys"
    chmod 600 "$HOME_DIR/.ssh/authorized_keys"
fi

# Setup host SSH key for the sshbox so it doesn't change on each image change.
if [ ! -f /etc/ssh/hostkeys/ssh_host_ed25519_key ]; then
    ssh-keygen -t ed25519 \
        -f /etc/ssh/hostkeys/ssh_host_ed25519_key \
        -N ''
fi

check_network_blocked() {
    failures="$(mktemp)"

    logdate() {
        date '+%Y-%m-%d %H:%M:%S'
    }

    check_host() {
        local host="$1"
        local description="$2"
        local port="${3:-80}"

        {
            if ping -c 1 -W 1 "$host" >/dev/null 2>&1; then
                echo "$(logdate) ERROR: $description ($host) is reachable via ICMP." >> "$failures"
            fi
        } &

        {
            if nc -z -w 2 "$host" "$port" >/dev/null 2>&1; then
                echo "$(logdate) ERROR: outbound connectivity exists to $description ($host):$port" >> "$failures"
            fi
        } &
    }

    echo "$(logdate) Checking that outgoing network traffic is blocked..."

    # Internet checks
    check_host 1.1.1.1 "Cloudflare" 80
    check_host 1.1.1.1 "Cloudflare DNS" 53

    # Common local network checks
    check_host 10.0.0.1 "Router" 80
    check_host 10.0.0.2 "Host" 80
    check_host 192.168.0.1 "Router" 80
    check_host 192.168.1.1 "Router" 80

    wait

    if [ -s "$failures" ]; then
        cat "$failures"
        rm -f "$failures"
        echo "$(logdate) Refusing to start service due to unblocked network detected."
        # Slow it down in case it auto restarts
        sleep 5
        exit 1
    fi

    rm -f "$failures"
}

check_network_blocked

echo "$(logdate) Outgoing network block appears active. Starting service..."

# -e logs to stderr, visible with: docker logs sshbox
exec /usr/sbin/sshd -D -e \
    -h /etc/ssh/hostkeys/ssh_host_ed25519_key
