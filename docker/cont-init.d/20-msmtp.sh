#!/bin/sh
set -e

# Configure msmtp so PHP's mail() / sendmail-mode mailers work.
#
# Either pass a full msmtp config via MSMTPRC (one env var, full file
# contents), or set the discrete SMTP_* vars below and this script will
# template a config for you.
#
#   SMTP_HOST      (required if not using MSMTPRC)
#   SMTP_PORT      (default: 587)
#   SMTP_USER
#   SMTP_PASS
#   SMTP_FROM      (default: baikal@$SMTP_HOST)
#   SMTP_TLS       ("off" to disable STARTTLS, default: on)

CONF=/etc/msmtprc

if [ -n "${MSMTPRC:-}" ]; then
    printf '%s\n' "$MSMTPRC" > "$CONF"
elif [ -n "${SMTP_HOST:-}" ]; then
    {
        echo "defaults"
        if [ "${SMTP_TLS:-on}" != "off" ]; then
            echo "tls on"
            echo "tls_starttls on"
        fi
        echo "account default"
        echo "host $SMTP_HOST"
        echo "port ${SMTP_PORT:-587}"
        [ -n "${SMTP_USER:-}" ] && echo "auth on" && echo "user $SMTP_USER"
        [ -n "${SMTP_PASS:-}" ] && echo "password $SMTP_PASS"
        echo "from ${SMTP_FROM:-baikal@$SMTP_HOST}"
        echo "logfile /dev/stdout"
    } > "$CONF"
else
    echo "10-msmtp: no MSMTPRC or SMTP_HOST set, mail() will not work" >&2
    exit 0
fi

chmod 600 "$CONF"
