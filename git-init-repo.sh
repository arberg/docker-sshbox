#!/bin/sh

DIR="$1"

ssh tower-sshbox <<EOF
mkdir -p "/git/$DIR"
cd "/git/$DIR"
git init --bare
EOF
