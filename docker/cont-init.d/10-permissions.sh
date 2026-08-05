#!/bin/sh
set -e

# Baikal needs to write its sqlite db / config here on first boot.
mkdir -p /var/www/baikal/Specific/db

# Only chown the two VOLUME-mounted paths, not the whole tree. Everything
# else (vendor/, Core/, html/) is already owned by nginx:nginx from the
# build
if [ -z "${BAIKAL_SKIP_CHOWN:-}" ]; then
    chown -R nginx:nginx /var/www/baikal/Specific /var/www/baikal/config
fi
