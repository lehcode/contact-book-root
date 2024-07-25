ARG mysql_version
FROM mysql:${mysql_version}

ARG user
ARG debug
ARG gid
ARG uid
ARG tz

COPY my.cnf /etc/my.cnf

RUN if [ -n "${debug}" ]; then set -eux; fi && \
  echo ${tz} > /etc/timezone && \
  groupadd -g ${gid} docker && \
  useradd -g docker --uid ${uid} -d /home/${user} -s /bin/sh ${user} && \
  usermod --groups root ${user} && \
  chown -R ${user}:docker /var/lib/mysql
