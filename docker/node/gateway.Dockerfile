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
    
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ -n "${debug}" ]; then set -eux; fi && \
    npm install -g npm@latest && \
    corepack enable && \
    yarn init -2 && \
    yarn set version stable && yarn install && \
    if [ -z "${debug}" ]; then apt cache clear; fi

RUN if [ -n "${debug}" ]; then set -eux; fi && \
    echo "${USER}\t\tALL=(ALL:ALL)\tNOPASSWD:ALL" | tee --append /etc/sudoers > /dev/null

COPY api/gateway/package.json .
COPY api/gateway/package-lock.json .

RUN npm install --omit=dev

USER ${USER}:docker

CMD [ "npm", "run", "dev" ]
