ARG php_version
FROM php:${php_version:-8.2}-fpm-bookworm

ARG uid
ARG gid
ARG user
ARG app_root
ARG debug
ARG tz

ENV UID=${uid}
ENV GID=${gid}
ENV APP_ROOT=${app_root}
ENV TZ=${tz}

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
COPY ./docker/php-fpm/php.dev.ini /usr/local/etc/php/php.ini
COPY ./docker/php-fpm/www.conf /usr/local/etc/php-fpm.d/www.conf

RUN if [ -n "${debug}" ]; then set -eux; fi && \
    apt-get -q update && \
    ln -fs /usr/share/zoneinfo/${tz} /etc/localtime && \
    echo ${tz} > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    addgroup --gid ${gid} docker && \
    echo Y | adduser --ingroup docker --disabled-password --uid ${uid} --home /home/${user} --shell /bin/sh ${user} && \
    usermod --groups www-data,root ${user} && \
    apt-get -qy install --no-install-recommends sudo tzdata locales && \
    echo "${user} ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/${user} && \
    apt-get -qy upgrade

WORKDIR ${app_root}