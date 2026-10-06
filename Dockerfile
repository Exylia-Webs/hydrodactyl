# TODO: Refactor Docker with stricter permissions & modernized tooling

# Stage 0:
# Build the frontend (only if not in dev mode)
FROM --platform=$TARGETOS/$TARGETARCH node:lts-alpine AS frontend
ARG DEV=false
WORKDIR /app
RUN if [ "$DEV" = "false" ]; then \
    apk add --no-cache git \
    && npm install -g corepack@latest turbo \
    && corepack enable \
    && echo "Building frontend"; \
    fi
COPY pnpm-lock.yaml package.json ./
RUN if [ "$DEV" = "false" ]; then \
    pnpm fetch \
    && echo "Fetched dependencies"; \
    fi
COPY . .
RUN if [ "$DEV" = "false" ]; then \
    CI=true pnpm install --frozen-lockfile \
    && pnpm run ship; \
    else \
    mkdir -p public/assets public/build; \
    fi

# Stage 1:
# Build the actual container with all of the needed PHP dependencies that will run the application
FROM --platform=$TARGETOS/$TARGETARCH php:8.4-fpm-alpine AS php
ARG DEV=false
WORKDIR /app

# Build-time deps & PHP extensions
RUN apk add --no-cache --virtual .build-deps \
    libpng-dev libxml2-dev libzip-dev postgresql18-dev \
    && docker-php-ext-configure zip \
    && docker-php-ext-install bcmath gd pdo pdo_mysql pdo_pgsql zip \
    && apk del .build-deps \
    && apk add --no-cache \
    libpng libxml2 libzip libpq

# Runtime packages
RUN apk add --no-cache \
    ca-certificates curl git supervisor nginx dcron \
    tar unzip certbot certbot-nginx mysql-client postgresql18-client \
    && ln -s /bin/ash /bin/bash

# Composer packages first, from the manifests only: this layer is reused until composer.lock
# changes instead of downloading every package on each build. Scripts and the autoloader need
# the application code, so they run once it is copied.
RUN curl -sS https://getcomposer.org/installer \
    | php -- --install-dir=/usr/local/bin --filename=composer
COPY composer.json composer.lock ./
RUN --mount=type=cache,target=/root/.composer/cache \
    if [ "$DEV" = "false" ]; then \
    composer install --no-dev --no-scripts --no-autoloader --prefer-dist; \
    else \
    composer install --no-scripts --no-autoloader; \
    fi

# Copy the application and the frontend build
COPY . ./
RUN if [ "$DEV" = "false" ]; then \
    echo "Copying frontend build"; \
    else \
    mkdir -p public/assets public/build; \
    fi
COPY --from=frontend /app/public/assets public/assets
COPY --from=frontend /app/public/build public/build

# Autoloader and package scripts, now that the code is in place
RUN if [ "$DEV" = "false" ]; then \
    composer dump-autoload --no-dev --optimize; \
    else \
    composer dump-autoload; \
    fi

# Clean up image for dev environment
# This is because we share local files with the container
RUN if [ "$DEV" = "true" ]; then \
    echo "Cleaning up"; \
    find . \
    -mindepth 1 \
    \( -path './vendor*' \) -prune \
    -o \
    -exec rm -rf -- {} \; \
    >/dev/null 2>&1; \
    fi; \
    exit 0

# Env, directories, permissions
RUN mkdir -p bootstrap/cache storage/logs storage/framework/sessions storage/framework/views storage/framework/cache; \
    rm -rf bootstrap/cache/*.php; \
    chown -R nginx:nginx .; \
    chmod -R 777 bootstrap storage; \
    cp .env.example .env || true;

# Cron jobs & NGINX tweaks
RUN rm /usr/local/etc/php-fpm.conf \
    && { \
    echo "* * * * * /usr/local/bin/php /app/artisan schedule:run >> /dev/null 2>&1"; \
    echo "0 23 * * * certbot renew --nginx --quiet"; \
    } > /var/spool/cron/crontabs/root \
    && sed -i 's/ssl_session_cache/#ssl_session_cache/' /etc/nginx/nginx.conf \
    && mkdir -p /var/run/php /var/run/nginx

# Configs
COPY --chown=nginx:nginx .github/docker/default.conf /etc/nginx/http.d/default.conf
COPY --chown=nginx:nginx .github/docker/www.conf     /usr/local/etc/php-fpm.conf
COPY --chown=nginx:nginx .github/docker/supervisord.conf /etc/supervisord.conf

RUN rm -rf bootstrap/cache/*.php \
    && rm -rf storage/framework/* || true

EXPOSE 80 443

# Coolify reads this for its rolling updates: it waits the start period, then one interval between
# probes. The entrypoint waits for the database and migrates before nginx answers, hence the
# retries. Anything below 500 means the panel answers (/ redirects to the login).
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=18 \
    CMD sh -c 'c=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/); [ "$c" -ge 200 ] && [ "$c" -lt 500 ]'
ENTRYPOINT [ "/bin/ash", ".github/docker/entrypoint.sh" ]
CMD [ "supervisord", "-n", "-c", "/etc/supervisord.conf" ]
