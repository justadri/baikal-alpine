# baikal-alpine — PHP 8.4 + nginx + Baikal (CalDAV/CardDAV), single container
# Based on sabre-io/Baikal: https://github.com/sabre-io/Baikal

ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-fpm-alpine

ARG BAIKAL_VERSION=0.11.1
ARG S6_OVERLAY_VERSION=3.2.0.2

# --- system packages -------------------------------------------------------
RUN apk add --no-cache \
        nginx \
        msmtp \
        unzip \
        wget \
        xz \
        tzdata \
        su-exec

# --- PHP extensions ---------------------------------------------------------
# Uses mlocati/docker-php-extension-installer: resolves the right -dev/apk
# packages for Alpine automatically and skips extensions already compiled
# into the base image (dom/simplexml/xml are already there; this just makes
# sure the full requested set is present).
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions \
        pdo_sqlite \
        sqlite3 \
        pdo_mysql \
        mysqli \
        pdo_pgsql \
        pgsql \
        dom \
        simplexml \
        xml \
        curl \
        mbstring \
        ctype \
        iconv \
        zip \
        opcache

# --- s6-overlay (process supervision for php-fpm + nginx) ------------------
RUN ARCH=$(uname -m) && \
    wget -qO /tmp/s6-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" && \
    wget -qO /tmp/s6-arch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${ARCH}.tar.xz" && \
    tar -C / -Jxpf /tmp/s6-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-arch.tar.xz && \
    rm -f /tmp/s6-*.tar.xz && \
    apk del xz

# --- Baikal itself ------------------------------------------------------
RUN wget -qO /tmp/baikal.zip "https://github.com/sabre-io/Baikal/releases/download/${BAIKAL_VERSION}/baikal-${BAIKAL_VERSION}.zip" && \
    unzip -q /tmp/baikal.zip -d /tmp && \
    mv /tmp/baikal /var/www/baikal && \
    rm -f /tmp/baikal.zip && \
    mkdir -p /var/www/baikal/Specific/db && \
    chown -R nginx:nginx /var/www/baikal

# --- config ------------------------------------------------------------
COPY docker/nginx.conf /etc/nginx/http.d/default.conf
COPY docker/php-fpm-pool.conf /usr/local/etc/php-fpm.d/zz-baikal.conf
COPY docker/php-baikal.ini /usr/local/etc/php/conf.d/zz-baikal.ini
COPY docker/cont-init.d/ /etc/cont-init.d/
COPY docker/services.d/ /etc/services.d/

RUN chmod +x /etc/cont-init.d/*.sh /etc/services.d/*/run

EXPOSE 80
VOLUME ["/var/www/baikal/config", "/var/www/baikal/Specific"]

ENTRYPOINT ["/init"]
