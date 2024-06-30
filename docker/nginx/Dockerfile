FROM nginx:stable-alpine

ARG uid
ARG gid
ARG user
ARG debug

ENV UID=${uid}
ENV GID=${gid}

# MacOS staff group's gid is 20, so is the dialout group in alpine linux. We're not using it, let's just remove it.
RUN delgroup dialout

RUN --mount=type=cache,target=/var/cache/apk,sharing=locked \
  if [ -n "${debug}" ]; then set -eux; fi && \
  mkdir -p /var/cache/apk && ln -s /var/cache/apk /etc/apk/cache && \
  apk update && apk upgrade

RUN addgroup -g ${GID} ${user} && \
  addgroup --system docker && \
  adduser -G docker --system -D -s /bin/sh -u ${UID} ${user} && \
  sed -i "s/user  nginx/user ${user}/g" /etc/nginx/nginx.conf

COPY default.conf /etc/nginx/conf.d/

RUN mkdir -p /var/www/html