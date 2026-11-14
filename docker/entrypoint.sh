#!/bin/bash
set -e

# Ensure Laravel storage directories exist with appropriate permissions
mkdir -p /var/www/html/storage/framework/cache/data \
         /var/www/html/storage/framework/sessions \
         /var/www/html/storage/framework/views \
         /var/www/html/storage/logs \
         /var/www/html/bootstrap/cache

# Fix directory ownership and permissions for www-data
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true

# Check and copy .env if missing
if [ ! -f /var/www/html/.env ]; then
    if [ -f /var/www/html/.env.docker.example ]; then
        echo "[JewelERP Docker] .env file not found. Initializing from .env.docker.example..."
        cp /var/www/html/.env.docker.example /var/www/html/.env
    elif [ -f /var/www/html/.env.example ]; then
        echo "[JewelERP Docker] .env file not found. Initializing from .env.example..."
        cp /var/www/html/.env.example /var/www/html/.env
    fi
fi

# Auto-generate APP_KEY if missing in .env
if [ -f /var/www/html/.env ] && [ -d /var/www/html/vendor ]; then
    if ! grep -q "^APP_KEY=base64:" /var/www/html/.env; then
        echo "[JewelERP Docker] Generating Laravel application key..."
        php artisan key:generate --force || true
    fi
fi

# Inform if vendor directory is missing
if [ ! -d /var/www/html/vendor ]; then
    echo "[JewelERP Docker] Notice: vendor/ directory not found in /var/www/html."
    echo "[JewelERP Docker] Run: docker compose exec app composer install"
fi

# Check if Vite build assets are missing
if [ ! -f /var/www/html/public/build/manifest.json ]; then
    if [ -d /var/www/html/node_modules ]; then
        echo "[JewelERP Docker] Compiling frontend assets via npm run build..."
        npm run build || true
    else
        echo "[JewelERP Docker] Notice: public/build/manifest.json not found."
        echo "[JewelERP Docker] Run: docker compose exec app npm install && docker compose exec app npm run build"
    fi
fi

exec "$@"
