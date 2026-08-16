#!/bin/sh
set -eu

sshbox() {
    # ssh connects to correct userid 'sshbox'. 
    # docker connects as root, and requires chown inside docker afterwards to fix permissions 'chown -R sshbox:users "$repo"'
    # docker exec sshbox "$@"
    ssh tower-sshbox "$@"
}

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 /git/path/to/repository" >&2
    exit 1
fi

repo="$1"

case "$repo" in
    /git/*) ;;
    *)
        echo "Error: repository path must start with /git/" >&2
        exit 1
        ;;
esac

if sshbox test -e "$repo"; then
    echo "Error: path already exists: $repo" >&2
    exit 1
fi

echo "Creating bare Git repository: $repo"

sshbox mkdir -p "$repo"
sshbox git init --bare "$repo"

