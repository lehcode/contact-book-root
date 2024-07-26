ARG php_version
FROM php:${php_version:-8.2}-fpm-bookworm

ARG uid
ARG gid
ARG user
ARG debug
ARG app_root
ARG tz
ARG redis_version

ENV UID=${uid}
ENV GID=${gid}
ENV APP_ROOT=${app_root}
ENV DEBIAN_FRONTEND=noninteractive

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    apt-get -q update && \
    apt-get -yq install --no-install-recommends --no-install-suggests sudo \
        tzdata locales wget && \
    ln -fs /usr/share/zoneinfo/${tz} /etc/localtime && \
    echo ${tz} > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    addgroup --gid ${gid} docker && \
    echo Y | adduser --ingroup docker --disabled-password --uid ${uid} --home /home/${user} --shell /bin/sh ${user} && \
    usermod --groups www-data,root ${user} && \
    echo "${user} ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/${user}

RUN --mount=type=cache,target=/usr/src/php,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    mkdir -p /usr/src/php/ext/redis && \
    curl -fsSL "https://github.com/phpredis/phpredis/archive/${redis_version}.tar.gz" | tar xvz -C /usr/src/php/ext/redis --strip 1 && \
    docker-php-ext-configure redis && \
    docker-php-ext-install redis

RUN if [ -n "${debug}" ]; then set -eux; fi && \
    echo "html_errors = Off" | tee -a /usr/local/etc/php/conf.d/cli.ini && \
    echo "log_errors = On" | tee -a /usr/local/etc/php/conf.d/cli.ini && \
    echo "error_reporting = E_ALL" | tee -a /usr/local/etc/php/conf.d/cli.ini && \
    echo "error_log = /var/log/php-cli/error.log" | tee -a /usr/local/etc/php/conf.d/cli.ini && \
    echo "display_errors = On" | tee -a /usr/local/etc/php/conf.d/cli.ini

ADD --checksum=sha256:df9c563abd70bb9b2fb1be7d11868a300bd60023bcd60700f24430008059a704 https://dev.mysql.com/get/mysql-apt-config_0.8.32-1_all.deb /tmp/

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    apt-get -y install /tmp/mysql-apt-config_0.8.32-1_all.deb && \
    apt-get update

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    apt-get -y install mysql-common mysql-client

WORKDIR ${app_root}

RUN chown -R ${user}:docker ${app_root}

USER ${user}:docker