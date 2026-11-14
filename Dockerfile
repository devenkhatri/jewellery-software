# Version: 2026-11
# JewelERP PHP 8.4 & Nginx Multi-Stage Dockerfile

# ==============================================================================
# Stage 1: Frontend Asset Compilation (Vite + Tailwind v4 + Alpine.js + Chart.js)
# ==============================================================================
FROM node:22-alpine AS frontend
WORKDIR /app

# Copy dependency manifests
COPY package.json package-lock.json ./

# Install npm dependencies (ignore lifecycle scripts for clean container build)
RUN npm ci --ignore-scripts || npm install --ignore-scripts

# Copy frontend source files and config
COPY vite.config.js ./
COPY resources ./resources
COPY public ./public

# Build compiled production assets to public/build
RUN npm run build

# ==============================================================================
# Stage 2: Base PHP 8.4 Runtime with Extensions and Composer
# ==============================================================================
FROM php:8.4-fpm-alpine AS base

WORKDIR /var/www/html

# Install core runtime utilities & build tools
RUN apk add --no-cache \
    bash \
    curl \
    git \
    unzip \
    libzip-dev \
    icu-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    oniguruma-dev \
    mariadb-client \
    shadow \
    su-exec

# Install official extension installer for reliable extension compilation
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Install required Laravel & JewelERP PHP extensions
RUN install-php-extensions \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    intl \
    zip \
    opcache \
    redis

# Install Composer 2 from official image
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Copy custom PHP configuration
COPY docker/php/local.ini /usr/local/etc/php/conf.d/local.ini
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# Copy entrypoint script
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Configure www-data user & permissions
RUN usermod -u 1000 www-data && groupmod -g 1000 www-data

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]

# ==============================================================================
# Stage 3: Development Image
# ==============================================================================
FROM base AS development

ENV APP_ENV=local
ENV APP_DEBUG=true

# Keep default entrypoint & php-fpm
EXPOSE 9000
CMD ["php-fpm"]

# ==============================================================================
# Stage 4: Production Image
# ==============================================================================
FROM base AS production

ENV APP_ENV=production
ENV APP_DEBUG=false

# Copy entire application codebase
COPY . /var/www/html

# Copy compiled frontend assets from frontend stage
COPY --from=frontend /app/public/build /var/www/html/public/build

# Install production PHP dependencies without dev packages
RUN composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist

# Set ownership and permissions for Laravel writable directories
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache && \
    chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 9000
CMD ["php-fpm"]
