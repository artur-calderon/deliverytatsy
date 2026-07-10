FROM php:8.3-fpm-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    unzip \
    curl \
    libicu-dev \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libxml2-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    bcmath \
    exif \
    gd \
    intl \
    pdo_mysql \
    zip \
    opcache \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY docker/php/php.ini /usr/local/etc/php/conf.d/zz-tastyigniter.ini
COPY docker/php/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p /var/www/html \
    && chown -R www-data:www-data /var/www/html


# Traduções pt-BR do TastyIgniter (copiadas para /var/www/html no entrypoint)
COPY tastyigniter/v4-admin/pt_BR/4.x/admin.php /usr/local/share/tastyigniter-lang/pt_BR/admin.php
COPY tastyigniter/v4-admin/pt_BR/4.x/main.php /usr/local/share/tastyigniter-lang/pt_BR/main.php
COPY tastyigniter/v4-admin/pt_BR/4.x/system.php /usr/local/share/tastyigniter-lang/pt_BR/system.php


WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
