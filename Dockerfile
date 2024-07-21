ARG php_version
FROM php:${php_version:-8.2}-fpm-bookworm

ARG uid
ARG gid
ARG user
ARG app_root
ARG redis_version
ARG debug
ARG tz
ARG arch=x86_64-pc-linux-gnu

ENV UID=${uid}
ENV GID=${gid}
ENV APP_ROOT=${app_root}
ENV CPPFLAGS="-I/usr/local/lib/"
ENV TZ=${tz}

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# MacOS staff group's gid is 20, so is the dialout group in alpine linux. We're not using it, let's just remove it.
RUN delgroup dialout

RUN if [ -n "${debug}" ]; then set -eux; fi && \
    addgroup --gid ${gid} docker && \
    adduser --gid ${gid} --uid ${uid} --home /home/${user} --shell /bin/sh ${user} && \
    usermod --groups www-data,root ${user}

COPY docker/php-fpm/php.dev.ini /usr/local/etc/php/php.ini

# RUN --mount=type=cache,target=/var/cache/apk,sharing=locked \
#     if [ -n "${debug}" ]; then set -eux; fi && \
#     apk add php-pecl-xdebug php-pecl-redis && \
#     if [ -z ${debug} ]; then apk cache clean; fi

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    # mkdir -p /var/cache/apk && ln -s /var/cache/apk /etc/apk/cache && \
    apt-get update && \
    apt-get -y install --no-install-recommends --no-install-suggests tzdata locales && \
    ln -fs /usr/share/zoneinfo/${tz} /etc/localtime && \
    echo ${tz} > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get -y upgrade

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get -y install build-essential curl net-tools zip unzip \
    cpanminus mysql-common bzip2
    # zlib1g-dev \
    # libzip-dev \
    # jpegoptim \
    # optipng \
    # pngquant \
    # gifsicle \
    # libonig-dev \
    # libicu-dev 

RUN --mount=type=cache,target=/usr/src/php,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    mkdir -p /usr/src/php/ext/xdebug && \
    curl -fsSL "https://xdebug.org/files/xdebug-3.3.2.tgz" | tar xvz -C /usr/src/php/ext/xdebug --strip 1 && \
    docker-php-ext-configure xdebug && \
    docker-php-ext-install xdebug

ENV ORACLE_HOME=/opt/oracle
ENV LD_LIBRARY_PATH=${ORACLE_HOME}/instantclient_23_4:${LD_LIBRARY_PATH}

WORKDIR ${ORACLE_HOME}

ADD --checksum=sha256:63835bf433b6b3e212082dfbd55662830d2104d71cc7e750cecda039726fe956 https://download.oracle.com/otn_software/linux/instantclient/2340000/instantclient-basic-linux.x64-23.4.0.24.05.zip ${ORACLE_HOME}/
ADD --checksum=sha256:8c1b596c515121e280b555b2957baf363f3164dbff0c20a064d5c30551700d8d https://download.oracle.com/otn_software/linux/instantclient/2340000/instantclient-sdk-linux.x64-23.4.0.24.05.zip ${ORACLE_HOME}/

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    unzip -o instantclient-basic-linux.x64-23.4.0.24.05.zip && \
    unzip -o instantclient-sdk-linux.x64-23.4.0.24.05.zip && \
    apt-get install -y libaio1 libicu-dev libpspell-dev libsnmp-dev libxml2-dev libpq-dev \
        libgmp-dev libkrb5-dev libc-client-dev libffi-dev libsodium-dev && \
    sh -c "echo /opt/oracle/instantclient_23_4 > /etc/ld.so.conf.d/oracle-instantclient.conf" && \
    ldconfig

RUN --mount=type=cache,target=/usr/src/php,sharing=locked \
    docker-php-ext-configure oci8 --with-oci8=instantclient,/opt/oracle/instantclient_23_4 && \
    docker-php-ext-configure pspell && \
    docker-php-ext-install -j4 intl pspell gettext && \
    docker-php-ext-install -j4 snmp && \
    docker-php-ext-configure pdo mysqli pdo_mysql pdo_pgsql pgsql --host=${arch} --target=${arch} && \
    docker-php-ext-install -j4 pdo mysqli pdo_mysql pdo_pgsql pgsql && \
    docker-php-ext-configure gmp --host=${arch} && \
    docker-php-ext-install -j4 gmp && \
    docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
    docker-php-ext-install -j4 imap && \
    docker-php-ext-configure bcmath && \
    docker-php-ext-install -j4 bcmath && \
    docker-php-ext-install -j4 fileinfo && \
    docker-php-ext-install -j4 exif && \
    docker-php-ext-install -j4 sockets sodium && \
    docker-php-ext-configure soap && \
    docker-php-ext-install -j4 soap && \
    docker-php-ext-configure snmp shmop --host=${arch} --target=${arch} && \
    docker-php-ext-install -j4 snmp shmop && \
    docker-php-ext-configure pcntl && \
    docker-php-ext-install -j4 pcntl

RUN docker-php-ext-configure ftp && \
    docker-php-ext-install -j4 ftp && \
    echo "/usr/src/php/ext/ftp/modules" > /etc/ld.so.conf.d/php-ftp.conf && \
    docker-php-ext-configure calendar && \
    docker-php-ext-install -j4 calendar && \
    echo "/usr/src/php/ext/calendar/modules" > /etc/ld.so.conf.d/php-calendar.conf && \
    docker-php-ext-configure dba && \
    docker-php-ext-install -j4 dba && \
    echo "/usr/src/php/ext/dba/modules" > /etc/ld.so.conf.d/php-dba.conf && \
    ldconfig

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    apt-get -y install libtidy-dev && \
    docker-php-ext-configure tidy && \
    docker-php-ext-install -j4 tidy && \
    echo "/usr/src/php/ext/tidy/modules" > /etc/ld.so.conf.d/php-tidy.conf && \
    ldconfig && \
    # sysvmsg \
    # sysvsem \
    # sysvshm \
    apt-get -y install libxslt-dev && \
    docker-php-ext-configure xsl && \
    docker-php-ext-install -j4 xsl && \
    echo "/usr/src/php/ext/xsl/modules" > /etc/ld.so.conf.d/php-xsl.conf && \
    ldconfig

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    apt-get -y install libpng-dev libjpeg-dev libjpeg62-turbo-dev libavif-dev \
        libwebp-dev libfreetype6-dev libxpm-dev && \
    docker-php-ext-configure gd \
        --with-freetype --with-jpeg --with-avif --with-xpm --with-webp && \
    docker-php-ext-install gd
    
RUN --mount=type=cache,target=/usr/src/php,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    mkdir -p /usr/src/php/ext/redis && \
    curl -fsSL "https://github.com/phpredis/phpredis/archive/${redis_version}.tar.gz" | tar xvz -C /usr/src/php/ext/redis --strip 1 && \
    docker-php-ext-configure redis && \
    docker-php-ext-install redis && \
    # echo "/usr/src/php/ext/redis/modules" | tee -a /etc/ld.so.conf && \
    docker-php-ext-enable redis

RUN if [ -z "${debug}" ]; then docker-php-source delete; fi

COPY docker/php-fpm/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini
COPY docker/php-fpm/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY docker/php-fpm/www.conf /usr/local/etc/php-fpm.d/www.conf

# RUN if [ -n "${debug}" ]; then set -eux; fi && \
#     sed -i "s/user = www-data/user = ${user}/g" /usr/local/etc/php-fpm.d/www.conf && \
#     sed -i "s/group = www-data/group = docker/g" /usr/local/etc/php-fpm.d/www.conf && \
#     mkdir -p ${app_root}

WORKDIR ${app_root}

COPY api/laravel/ .


CMD ["php-fpm", "-y", "/usr/local/etc/php-fpm.conf", "-R"]
