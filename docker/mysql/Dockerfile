ARG mysql_version
FROM mysql:${mysql_version}

ARG user
ARG debug
ARG gid
ARG uid
ARG tz
ARG root_pass

COPY my.cnf /etc/mysql/conf.d/docker-my.cnf

RUN if [ -n "${debug}" ]; then set -eux; fi && \
  echo ${tz} > /etc/timezone && \
  groupadd -g ${gid} docker && \
  useradd -g docker --uid ${uid} -d /home/${user} -s /bin/sh ${user} && \
  usermod --groups root ${user} && \
  chmod 775 /var/lib/mysql && \
  chown -R ${user}:docker /var/lib/mysql /var/lib/mysql-files /var/lib/mysql-keyring
