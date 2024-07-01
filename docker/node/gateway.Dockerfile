ARG node_version
FROM node:${node_version}

ARG app_root
ARG user
ARG uid
ARG gid
ARG debug

ENV USER=${user}
ENV UID=${uid}
ENV GID=${gid}
ENV DEBUG=${debug}
ENV APP_ROOT=${app_root}

WORKDIR ${APP_ROOT}

RUN if [ -n "${debug}" ]; then set -eux; fi && \
    groupmod -g 1111 node && usermod -u 1111 -g 1111 node && \
    groupadd -g ${GID} docker && \
    useradd -m -d /home/${USER} -u ${UID} -g ${GID} ${USER} && \
    chmod 775 /home/${USER}
    
RUN if [ -n "${debug}" ]; then set -eux; fi && \
    npm install -g npm@latest > /dev/null && \
    corepack enable > /dev/null && \
    yarn init -2 > /dev/null && \
    yarn set version stable && yarn install

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    apt-get update > /dev/null && \
    apt-get -qy upgrade > /dev/null && \
    apt-get -qy install sudo net-tools > /dev/null && \
    echo "${USER}\t\tALL=(ALL:ALL)\tNOPASSWD:ALL" | tee --append /etc/sudoers && \
    if [ -z "${debug}" ]; then apt cache clear > /dev/null; fi

COPY api/gateway/yarn.lock .

RUN yarn install

USER ${USER}:docker

CMD [ "yarn", "dev" ]
