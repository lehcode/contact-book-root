FROM nginx:stable-alpine

ARG uid
ARG gid
ARG user
ARG debug
ARG app_root
ARG tz

ENV UID=${uid}
ENV GID=${gid}
ENV APP_ROOT=${app_root}

# MacOS staff group's gid is 20, so is the dialout group in alpine linux. We're not using it, let's just remove it.
RUN delgroup dialout

RUN --mount=type=cache,target=/var/cache/apk,sharing=locked \
  if [ -n "${debug}" ]; then set -eux; fi && \
  mkdir -p /var/cache/apk && ln -s /var/cache/apk /etc/apk/cache && \
  echo http://dl-2.alpinelinux.org/alpine/edge/community/ >> /etc/apk/repositories && \
  apk update && apk upgrade && \
  apk add -U shadow && \
  apk add tzdata && \
  addgroup --gid ${gid} docker && \
  adduser --ingroup docker --disabled-password --system --shell /bin/sh \
    --home /home/${user} --uid ${uid} ${user} && \
  usermod --groups www-data,root ${user} && \
  sed -i "s/#{0,1}user\s+nginx/user\\t${user}/g" /etc/nginx/nginx.conf &&\
  mkdir -p /etc/sudoers.d && \
  echo "${user} ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/${user} && \
  mkdir -p /etc/nginx/logs && \
  touch /etc/nginx/logs/error.log && \
  touch /etc/nginx/logs/access.log && \
  chown -R ${user}:docker /var/cache/nginx /etc/nginx && \
  ln -sf /usr/share/zoneinfo/${tz} /etc/localtime && \
  echo ${tz} > /etc/timezone

COPY default.conf /etc/nginx/conf.d/default.conf

RUN mkdir -p ${app_root}

WORKDIR ${app_root}