# baikal-alpine — PHP 8.4 + nginx + Baikal (CalDAV/CardDAV), single container
# Based on sabre-io/Baikal: https://github.com/sabre-io/Baikal

ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-fpm-alpine

ARG BAIKAL_VERSION=0.11.1
ARG S6_OVERLAY_VERSION=3.2.0.2

# these pin the minimum versions we force via `composer require` after unpacking,
# to pick up security fixes without waiting on a new Baikal release.
# see the composer update step below for details.
ARG TWIG_VERSION=^3.27.0
ARG SYMFONY_YAML_VERSION=^7.4.12

LABEL org.opencontainers.image.title="baikal-alpine" \
      org.opencontainers.image.description="Baikal (CalDAV/CardDAV server) on php:8.4-fpm-alpine + nginx, supervised by s6-overlay" \
      org.opencontainers.image.source="https://github.com/justadri/baikal-alpine" \
      org.opencontainers.image.documentation="https://github.com/justadri/baikal-alpine/blob/main/README.md" \
      org.opencontainers.image.licenses="GPL-3.0-only" \
      org.opencontainers.image.version="${BAIKAL_VERSION}" \
      org.opencontainers.image.base.name="docker.io/library/php:${PHP_VERSION}-fpm-alpine"

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

# --- dependency patch: bump twig/twig and symfony/yaml past known CVEs --
# fetch the actual composer.json from the matching git tag first,
# then require against that real manifest.
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN apk add --no-cache --virtual .composer-deps git && \
    cd /var/www/baikal && \
    wget -qO composer.json "https://raw.githubusercontent.com/sabre-io/Baikal/${BAIKAL_VERSION}/composer.json" && \
    composer require --no-interaction --no-progress --optimize-autoloader \
        "twig/twig:${TWIG_VERSION}" \
        "symfony/yaml:${SYMFONY_YAML_VERSION}" && \
    composer clear-cache && \
    chown -R nginx:nginx vendor composer.json && \
    [ -f composer.lock ] && chown nginx:nginx composer.lock; \
    apk del .composer-deps && \
    rm -f /usr/bin/composer

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
