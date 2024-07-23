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

# Install system packages and configure PHP extensions
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    apt-get -q update && \
    apt-get -yq install --no-install-recommends --no-install-suggests sudo \
        tzdata locales && \
    ln -fs /usr/share/zoneinfo/${tz} /etc/localtime && \
    echo ${tz} > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    addgroup --gid ${gid} docker && \
    adduser --ingroup docker --disabled-password --uid ${uid} --home /home/${user} --shell /bin/sh ${user} && \
    usermod --groups www-data,root ${user} && \
    echo "${user} ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/${user}

# Install additional system packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    apt-get -y upgrade && \
    apt-get -yq install --no-install-recommends build-essential curl \
    net-tools zip unzip cpanminus mysql-common bzip2 mc less nano

# Set environment variables for Oracle Instant Client
ENV ORACLE_HOME=/opt/oracle
ENV LD_LIBRARY_PATH=${ORACLE_HOME}/instantclient_23_4:${LD_LIBRARY_PATH}

# Set the working directory for Oracle Instant Client installation
WORKDIR ${ORACLE_HOME}

# Download and install Oracle Instant Client
ADD --checksum=sha256:63835bf433b6b3e212082dfbd55662830d2104d71cc7e750cecda039726fe956 https://download.oracle.com/otn_software/linux/instantclient/2340000/instantclient-basic-linux.x64-23.4.0.24.05.zip ${ORACLE_HOME}/
ADD --checksum=sha256:8c1b596c515121e280b555b2957baf363f3164dbff0c20a064d5c30551700d8d https://download.oracle.com/otn_software/linux/instantclient/2340000/instantclient-sdk-linux.x64-23.4.0.24.05.zip ${ORACLE_HOME}/

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    unzip -o instantclient-basic-linux.x64-23.4.0.24.05.zip && \
    unzip -o instantclient-sdk-linux.x64-23.4.0.24.05.zip && \
    sh -c "echo /opt/oracle/instantclient_23_4 > /etc/ld.so.conf.d/oracle-instantclient.conf" && \
    ldconfig

# Install system packages
RUN apt-get install -yq libaio1 libicu-dev libpspell-dev libsnmp-dev libxml2-dev libpq-dev \
        libgmp-dev libkrb5-dev libc-client-dev libffi-dev libsodium-dev libtidy-dev \
        libpng-dev libjpeg-dev libjpeg62-turbo-dev libavif-dev libwebp-dev \
        libfreetype6-dev libxpm-dev libxslt-dev

# Install PHP extensions
RUN --mount=type=cache,target=/usr/src/php,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    docker-php-ext-configure oci8 --with-oci8=instantclient,/opt/oracle/instantclient_23_4 && \
    docker-php-ext-configure pspell && \
    docker-php-ext-install -j4 intl pspell gettext && \
    docker-php-ext-configure pdo mysqli pdo_mysql pdo_pgsql pgsql --host=${arch} --target=${arch} && \
    docker-php-ext-install -j4 pdo mysqli pdo_mysql pdo_pgsql pgsql && \
    docker-php-ext-configure gmp --host=${arch} && \
    docker-php-ext-install -j4 gmp && \
    docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
    docker-php-ext-install -j4 imap && \
    docker-php-ext-configure bcmath && \
    docker-php-ext-install -j4 bcmath fileinfo exif sockets && \
    docker-php-ext-configure soap && \
    docker-php-ext-configure shmop && \
    docker-php-ext-configure snmp && \
    docker-php-ext-install -j4 soap snmp shmop && \
    docker-php-ext-configure pcntl && \
    docker-php-ext-install -j4 pcntl && \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-avif --with-xpm --with-webp && \
    docker-php-ext-install gd && \
    docker-php-ext-configure ftp && \
    if [ -n "${debug}" ]; then set -eux; fi && \
    docker-php-ext-install -j4 ftp && \
    docker-php-ext-configure calendar && \
    docker-php-ext-install -j4 calendar && \
    docker-php-ext-configure dba && \
    docker-php-ext-install -j4 dba && \
    docker-php-ext-configure tidy && \
    docker-php-ext-install -j4 tidy && \
    # sysvmsg \
    # sysvsem \
    # sysvshm \
    docker-php-ext-configure xsl && \
    docker-php-ext-install -j4 xsl
    
RUN mkdir -p /usr/src/php/ext/redis && \
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

# Copy configuration files for PHP and PHP-FPM
COPY docker/php-fpm/php.dev.ini /usr/local/etc/php/php.ini
COPY docker/php-fpm/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY docker/php-fpm/www.conf /usr/local/etc/php-fpm.d/www.conf
COPY docker/php-fpm/xdebug.ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# RUN if [ -n "${debug}" ]; then set -eux; fi && \
#     sed -i "s/#user = www-data/user = ${user}/g" /usr/local/etc/php-fpm.d/www.conf && \
#     sed -i "s/#group = www-data/group = docker/g" /usr/local/etc/php-fpm.d/www.conf && \
#     echo "php_admin_flag[log_errors] = on" | tee -a /usr/local/etc/php-fpm.d/www.conf && \
#     echo "php_admin_flag[display_errors] = on" | tee -a /usr/local/etc/php-fpm.d/www.conf && \
#     echo "php_admin_value[error_reporting] = E_ALL & ~E_DEPRECATED & ~E_STRICT" | tee -a /usr/local/etc/php-fpm.d/www.conf

# Set the working directory for the application
WORKDIR ${app_root}

# Copy the Laravel application source code into the Docker image
COPY api/laravel/ .

# Set file permissions and ownership for the application
RUN if [ -n "${debug}" ]; then set -eux; fi && \
    echo "<?php phpinfo(); ?>" > public/pinfo.php
    # chown -R ${user}:docker ${app_root}

# Clean up the apt cache to reduce the size of the Docker image
RUN if [ -z "${debug}" ]; then docker-php-source-delete; fi && \
    if [ -z "${debug}" ]; then rm -rf /var/lib/apt/lists/*; fi && \
    if [ -z "${debug}" ]; then apt-mark auto '.*' > /dev/null; fi && \
    if [ -z "${debug}" ]; then apt-get purge -y --auto-remove; fi

# Set the command to run when the Docker container starts
CMD ["php-fpm", "--force-stderr", "--nodaemonize", "-y", "/usr/local/etc/php-fpm.conf", "-R"]
