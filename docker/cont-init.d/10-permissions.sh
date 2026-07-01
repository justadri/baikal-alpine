#!/bin/sh
set -e

# Baikal needs to write its sqlite db / config here on first boot.
mkdir -p /var/www/baikal/Specific/db

if [ -z "${BAIKAL_SKIP_CHOWN:-}" ]; then
    chown -R nginx:nginx /var/www/baikal
fi
