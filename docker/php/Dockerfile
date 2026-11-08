# PHP 8.3 (patched against php2shell / CVE-2026-109618+109619 in current images).
# Gazelle was ported off PHP-7-only constructs (each(), create_function(), mcrypt,
# and the memcache extension) to run here.
FROM php:8.3-fpm

RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libzip-dev \
        libonig-dev \
        zlib1g-dev \
        libmemcached-dev \
        libssl-dev \
        libsasl2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" gd mysqli mbstring bcmath sockets zip \
    # Gazelle's CACHE class was ported from the old "memcache" extension (no PHP 8
    # build exists) to "memcached". mcrypt is gone — encrypt.class.php uses OpenSSL.
    && yes '' | pecl install memcached \
    && docker-php-ext-enable memcached \
    && rm -rf /var/lib/apt/lists/*

COPY zz-gazelle.ini /usr/local/etc/php/conf.d/zz-gazelle.ini

WORKDIR /var/www/gazelle
