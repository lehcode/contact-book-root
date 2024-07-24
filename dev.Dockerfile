ARG php_version
FROM php:${php_version:-8.2}-fpm-bookworm

# Define arguments for building the Docker image
ARG uid
ARG gid
ARG user
ARG app_root
ARG redis_version
ARG debug
ARG tz
ARG arch=x86_64-pc-linux-gnu

# Set environment variables
ENV UID=${uid}
ENV GID=${gid}
ENV APP_ROOT=${app_root}
ENV CPPFLAGS="-I/usr/local/lib/"
ENV TZ=${tz}

# Copy the latest Composer binary from the official Composer Docker image
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    apt-get -q update && \
    apt-get -yq install --no-install-recommends --no-install-suggests sudo \
        tzdata locales && \
    ln -fs /usr/share/zoneinfo/${tz} /etc/localtime && \
    echo ${tz} > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    addgroup --gid ${gid} docker && \
    echo Y | adduser --ingroup docker --disabled-password --uid ${uid} --home /home/${user} --shell /bin/sh ${user} && \
    usermod --groups www-data,root ${user} && \
    echo "${user} ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/${user}
    
# Install additional system packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    apt-get -y upgrade && \
    apt-get -yq install --no-install-recommends build-essential curl \
    net-tools zip unzip cpanminus mysql-common bzip2 mc less nano

RUN --mount=type=cache,target=/usr/src/php,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    mkdir -p /usr/src/php/ext/redis && \
    curl -fsSL "https://github.com/phpredis/phpredis/archive/${redis_version}.tar.gz" | tar xvz -C /usr/src/php/ext/redis --strip 1 && \
    docker-php-ext-configure redis && \
    docker-php-ext-install redis

RUN --mount=type=cache,target=/usr/src/php,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    mkdir -p /usr/src/php/ext/xdebug && \
    curl -fsSL "https://xdebug.org/files/xdebug-3.3.2.tgz" | tar xvz -C /usr/src/php/ext/xdebug --strip 1 && \
    docker-php-ext-configure xdebug && \
    docker-php-ext-install xdebug && \
    docker-php-ext-enable xdebug

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    apt-get -y install nginx nginx-extras && \
    mkdir -p ${app_root} /run/nginx && \
    chown -R ${user}:docker ${app_root} /var/log/nginx /run/nginx /etc/nginx

# Copy configuration files for PHP and PHP-FPM
# COPY docker/php-fpm/php.dev.ini /usr/local/etc/php/php.ini
COPY docker/php-fpm/www.conf /usr/local/etc/php-fpm.d/www.conf
COPY docker/php-fpm/xdebug.ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

RUN if [ -n "${debug}" ]; then set -eux; fi && \
    sed -i "s/user = www-data/user = ${user}/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i "s/group = www-data/group = docker/g" /usr/local/etc/php-fpm.d/www.conf

COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf

RUN if [ -n "${debug}" ]; then set -eux; fi && \
    # Update nginx user
    sed -i "s/user(\t|\s)+.+;/user "${user}" docker;/g" /etc/nginx/nginx.conf && \
    pid_path=$(printf '%s\n' "/run/nginx/nginx.pid" | sed 's/[\/&]/\\&/g') && \
    sed -i "s/pid \/run\/nginx\.pid;/pid "${pid_path}";/g" /etc/nginx/nginx.conf && \
    # Update server document root
    escaped_app_root=$(printf '%s\n' "$app_root" | sed 's/[.\/&]/\\&/g') && \
    sed -i "s/root \/var\/www\/html;/root "${escaped_app_root}";/g" /etc/nginx/conf.d/default.conf

# Set the working directory for the application
WORKDIR ${app_root}

# Copy the Laravel application source code into the Docker image
COPY api/laravel/ .

# Set file permissions and ownership for the application
RUN if [ -n "${debug}" ]; then set -eux; fi && \
    echo "<?php phpinfo(); ?>" > public/pinfo.php
    

# Clean up the apt cache to reduce the size of the Docker image
RUN if [ -z "${debug}" ]; then docker-php-source-delete; fi && \
    if [ -z "${debug}" ]; then rm -rf /var/lib/apt/lists/*; fi && \
    if [ -z "${debug}" ]; then apt-mark auto '.*' > /dev/null; fi && \
    if [ -z "${debug}" ]; then apt-get purge -y --auto-remove; fi

COPY docker/php-fpm/entrypoint.sh /start.sh

CMD [ "/start.sh" ]
