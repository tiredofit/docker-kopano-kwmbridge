FROM tiredofit/alpine:3.12 as kwmbridge-builder

ARG KWMBRIDGE_REPO_URL
ARG KWMBRIDGE_VERSION

ENV KWMBRIDGE_REPO_URL=${KWMBRIDGE_REPO_URL:-"https://github.com/Kopano-dev/kwmbridge"} \
    KWMBRIDGE_VERSION=${KWMBRIDGE_VERSION:-"v0.15.0"}

#ADD build-assets/kopano-KWMBRIDGE /build-assets

RUN set -x && \
    apk update && \
    apk upgrade && \
    apk add -t .KWMBRIDGE-build-deps \
                build-base \
                coreutils \
                gettext \
                git \
                go \
                tar \
                && \
    \
    git clone ${KWMBRIDGE_REPO_URL} /usr/src/KWMBRIDGE && \
    cd /usr/src/KWMBRIDGE && \
    git checkout ${KWMBRIDGE_VERSION} && \
    \
    if [ -d "/build-assets/src/kwmbridge" ] ; then cp -R /build-assets/src/kwmbridge/* /usr/src/kwmbridge ; fi; \
    if [ -f "/build-assets/scripts/kwmbridge.sh" ] ; then /build-assets/scripts/kwmbridge.sh ; fi; \
    \
    make && \
    mkdir -p /rootfs/usr/libexec/kopano/ && \
    cp -R ./bin/* /rootfs/usr/libexec/kopano/ && \
    mkdir -p /rootfs/tiredofit && \
    echo "kwmbridge ${KWMBRIDGE_VERSION} built from  ${KWMBRIDGE_REPO_URL} on $(date)" > /rootfs/tiredofit/kwmbridge.version && \
    echo "Commit: $(cd /usr/src/kwmbridge ; echo $(git rev-parse HEAD))" >> /rootfs/tiredofit/kwmbridge.version && \
    cd /rootfs && \
    tar cvfz /kopano-kwmbridge.tar.gz . && \
    cd / && \
    apk del .kwmbridge-build-deps && \
    rm -rf /usr/src/* && \
    rm -rf /var/cache/apk/* && \
    rm -rf /rootfs

FROM tiredofit/nginx:latest
LABEL maintainer="Dave Conroy (dave at tiredofit dot ca)"

ENV ENABLE_SMTP=FALSE \
    NGINX_ENABLE_CREATE_SAMPLE_HTML=FALSE \
    NGINX_LOG_ACCESS_LOCATION=/logs/nginx \
    NGINX_LOG_ERROR_LOCATION=/logs/nginx \
    NGINX_MODE=PROXY \
    NGINX_PROXY_URL=http://localhost:8777 \
    ZABBIX_HOSTNAME=kwmbridge-app

### Move Previously built files from builder image
COPY --from=kwmbridge-builder /*.tar.gz /usr/src/kwmbridge/

RUN set -x && \
    apk update && \
    apk upgrade && \
    apk add -t .kwmbridge-run-deps \
                mariadb-client \
                openssl \
                && \
    \
    ##### Unpack kwmbridge
    tar xvfz /usr/src/kwmbridge/kopano-kwmbridge.tar.gz -C / && \
    rm -rf /usr/src/* && \
    rm -rf /etc/kopano && \
    ln -sf /config /etc/kopano && \
    rm -rf /var/cache/apk/*

ADD install /
