ARG php_version
FROM php:${php_version:-8.2}-fpm-alpine

ARG uid
ARG gid
ARG user
ARG app_root
ARG redis_version
ARG debug

ENV UID=${uid}
ENV GID=${gid}
ENV APP_ROOT=${app_root}

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# MacOS staff group's gid is 20, so is the dialout group in alpine linux. We're not using it, let's just remove it.
RUN delgroup dialout

RUN if [ -n "${debug}" ]; then set -eux; fi && \
    addgroup -g ${GID} docker && \
    adduser -G docker --system -D -s /bin/sh -u ${UID} ${user}

RUN --mount=type=cache,target=/var/cache/apk,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    mkdir -p /var/cache/apk && ln -s /var/cache/apk /etc/apk/cache && \
    apk update && apk upgrade && \
    docker-php-ext-install pdo pdo_mysql && \
    mkdir -p /usr/src/php/ext/redis \
    && curl -L https://github.com/phpredis/phpredis/archive/${redis_version}.tar.gz | tar xvz -C /usr/src/php/ext/redis --strip 1 \
    && echo 'redis' >> /usr/src/php-available-exts \
    && docker-php-ext-install redis && \
    if [ -n ${debug} ]; then apk cache clean; fi

RUN if [ -n "${debug}" ]; then set -eux; fi && \
    sed -i "s/user = www-data/user = ${user}/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i "s/group = www-data/group = docker/g" /usr/local/etc/php-fpm.d/www.conf && \
    echo "php_admin_flag[log_errors] = on" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "php_admin_value[error_reporting] = E_ALL & ~E_DEPRECATED & ~E_STRICT" >> /usr/local/etc/php-fpm.d/www.conf && \
    mkdir -p ${app_root}

COPY api ${app_root}

CMD ["php-fpm", "-y", "/usr/local/etc/php-fpm.conf", "-R"]
