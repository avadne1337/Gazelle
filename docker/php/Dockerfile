FROM php:7.4-fpm-bullseye

# bullseye is EOL: its -security / -updates suites advertise package versions
# that have been purged from the mirror pool (404s). The base suite still
# serves everything we need, so drop the broken suites before updating.
RUN sed -i '/bullseye-security/d; /bullseye-updates/d' /etc/apt/sources.list

# System libraries needed to build the PHP extensions Gazelle requires.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libzip-dev \
        libonig-dev \
        libmcrypt-dev \
        zlib1g-dev \
        git \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" gd mysqli mbstring bcmath sockets zip \
    # mcrypt (removed from core in 7.2) and the old "memcache" extension that
    # Gazelle's CACHE class extends, both via PECL.
    && yes '' | pecl install mcrypt-1.0.4 memcache-4.0.5.2 \
    && docker-php-ext-enable mcrypt memcache \
    && apt-get purge -y --auto-remove \
    && rm -rf /var/lib/apt/lists/*

COPY zz-gazelle.ini /usr/local/etc/php/conf.d/zz-gazelle.ini

WORKDIR /var/www/gazelle
