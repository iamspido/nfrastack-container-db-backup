# syntax=docker/dockerfile:1.7

# Unofficial source build of:
#   https://github.com/nfrastack/container-base
#   https://github.com/nfrastack/container-db-backup
#
# Both upstream projects are pinned to release tags. Building container-base
# from source enables its advanced functionality according to the upstream
# documentation.

ARG ALPINE_VERSION=3.24
ARG CONTAINER_BASE_TAG=2026.7.0
ARG DB_BACKUP_TAG=4.9.0

FROM alpine:${ALPINE_VERSION}

ARG ALPINE_VERSION
ARG CONTAINER_BASE_TAG
ARG DB_BACKUP_TAG
ARG IMAGE_BASE_MODULES="+age,+cron,+logrotate,+fail2ban,+s6overlay,+msmtp,"
ARG IMAGE_MODULES=""
ARG IMAGE_BASE_VERSION="${ALPINE_VERSION}"
ARG IMAGE_BASE_REPO_URL="https://github.com/nfrastack/container-base"
ARG TIMEZONE="Etc/GMT"
ARG SOURCE_REPOSITORY="https://github.com/nfrastack/container-db-backup"
ARG VCS_REF=""

LABEL org.opencontainers.image.title="nfrastack-container-db-backup" \
      org.opencontainers.image.description="Unofficial source build of nfrastack/container-db-backup with a source-built container-base" \
      org.opencontainers.image.source="${SOURCE_REPOSITORY}" \
      org.opencontainers.image.url="${SOURCE_REPOSITORY}" \
      org.opencontainers.image.documentation="${SOURCE_REPOSITORY}#readme" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${DB_BACKUP_TAG}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.base.name="docker.io/library/alpine:${ALPINE_VERSION}" \
      org.opencontainers.image.base.version="${CONTAINER_BASE_TAG}"

ENV PATH="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/local/lib:/usr/sbin:/usr/bin:/sbin:/bin:/command" \
    S6_KEEP_ENV=1 \
    IMAGE_NAME="nfrastack/base" \
    IMAGE_REPO_URL="https://github.com/nfrastack/container-base/"

# -----------------------------------------------------------------------------
# Build nfrastack/container-base from its pinned source tag.
# -----------------------------------------------------------------------------

RUN set -eux; \
    apk add --no-cache bash ca-certificates git; \
    git clone --depth 1 --branch "${CONTAINER_BASE_TAG}" \
        https://github.com/nfrastack/container-base.git \
        /usr/src/container-base; \
    mkdir -p \
        /usr/src/build_image \
        /usr/share/licenses/nfrastack-container-db-backup; \
    cp -a /usr/src/container-base/rootfs/. /; \
    cp /usr/src/container-base/CHANGELOG.md /usr/src/build_image/CHANGELOG.md; \
    cp /usr/src/container-base/LICENSE /usr/src/build_image/LICENSE; \
    cp /usr/src/container-base/README.md /usr/src/build_image/README.md; \
    cp /usr/src/container-base/LICENSE \
        /usr/share/licenses/nfrastack-container-db-backup/container-base-MIT.txt

SHELL ["/bin/bash", "-c"]

# This follows the build logic of the pinned upstream container-base
# Containerfile. The core module set matches the upstream core image workflow.
RUN echo "" && \
    source /container/base/functions/container/build && \
    case "$(container_info distro)" in \
        alpine ) \
            if [ "$(grep -o '^PRETTY_NAME=.*' /etc/os-release | cut -d = -f2)" = '"Alpine Linux edge"' ] ; then \
                apk add merge-usr ; \
                merge-usr ; \
            fi ; \
            case "$(container_info variant)" in \
                3.[5-9] | 3.1[1-6] ) alpine_ssl=libressl ;; \
                3.1[7-9] | 3.2[0-9] ) alpine_ssl=openssl ;; \
            esac ; \
            case "$(container_info variant)" in \
                3.[5-8] ) zstd_package="" ;; \
                * ) zstd_package="zstd" ;; \
            esac ; \
            IMAGE_BASE_BUILD_DEPS_ALPINE="gettext musl-dev" ; \
            IMAGE_BASE_RUN_DEPS_ALPINE="acl ${alpine_ssl} bash ${busybox_extras} ca-certificates curl git grep libgcc $(apk search libssl1* -q) nano sudo tzdata xz ${zstd_package}" ; \
        ;; \
        debian ) \
            IMAGE_BASE_BUILD_DEPS_DEBIAN="" ; \
            IMAGE_BASE_RUN_DEPS_DEBIAN="acl apt-transport-https apt-utils aptitude busybox-static ca-certificates curl dirmngr gettext git gnupg nano procps sudo tar tzdata zstd" ; \
        ;; \
    esac ; \
    package update && \
    package upgrade && \
    package install IMAGE_BASE_BUILD_DEPS IMAGE_BASE_RUN_DEPS && \
    mkdir -p /etc/bash/ /run/secrets /usr/local/bin /usr/local/sbin && \
    if [ -e /usr/bin/envsubst ] ; then \
        mv /usr/bin/envsubst /usr/local/bin/envsubst ; \
    fi && \
    container_build_log base && \
    rm -rf /etc/timezone && \
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    case "$(container_info distro)" in \
        debian ) \
            dpkg-reconfigure -f noninteractive tzdata ; \
            rm -rf /usr/bin/crontab /usr/sbin/cron ; \
            busybox --install -s /usr/bin ; \
        ;; \
    esac ; \
    _container_modules_parse IMAGE_BASE_MODULES && \
    _container_modules_parse IMAGE_MODULES && \
    package remove IMAGE_BASE_BUILD_DEPS && \
    package cleanup && \
    rm -rf \
        /container/base/modules \
        /etc/*.apk.new \
        /etc/cron* \
        /etc/issue \
        /etc/periodic/{*,.??*} \
        /etc/profile.d/{*,.??*} \
        /media \
        /usr/share/gnome/help/*/{*,.??*} \
        /usr/share/info/{*,.??*} \
        /usr/share/linda \
        /usr/share/lintian/overrides \
        /usr/share/omf \
        /usr/src/container-base

# -----------------------------------------------------------------------------
# Build nfrastack/container-db-backup from its pinned source tag.
# -----------------------------------------------------------------------------

ARG AWS_CLI_VERSION=1.44.56
ARG INFLUX1_CLIENT_VERSION=1.8.0
ARG INFLUX2_CLIENT_VERSION=2.7.5
ARG MSODBC_VERSION=18.6.1.1-1
ARG MSSQL_VERSION=118.6.1.1-1
ARG MYSQL_VERSION=mysql-9.7.2
ARG MYSQL_REPO_URL=https://github.com/mysql/mysql-server

ENV CONTAINER_ENABLE_SCHEDULING=TRUE \
    IMAGE_NAME="nfrastack/db-backup" \
    IMAGE_REPO_URL="https://github.com/nfrastack/container-db-backup/"

RUN set -eux; \
    git clone --depth 1 --branch "${DB_BACKUP_TAG}" \
        https://github.com/nfrastack/container-db-backup.git \
        /usr/src/container-db-backup; \
    mkdir -p /usr/src/container /build-context/db-rootfs; \
    cp /usr/src/container-db-backup/CHANGELOG.md /usr/src/container/CHANGELOG.md; \
    cp /usr/src/container-db-backup/LICENSE /usr/src/container/LICENSE; \
    cp /usr/src/container-db-backup/README.md /usr/src/container/README.md; \
    cp /usr/src/container-db-backup/LICENSE \
        /usr/share/licenses/nfrastack-container-db-backup/container-db-backup-MIT.txt; \
    cp -a /usr/src/container-db-backup/rootfs/. /build-context/db-rootfs/

# This follows the build logic of the pinned upstream container-db-backup
# Containerfile. Native AMD64 and ARM64 builds are handled by GitHub Actions.
RUN echo "" && \
    source /container/base/functions/container/build && \
    container_build_log image && \
    set -ex && \
    create_user dbbackup 10000 dbbackup 10000 /data/backup && \
    DBBACKUP_BUILD_DEPS_ALPINE="build-base bzip2-dev cargo cmake curl-dev git go libarchive-dev libffi-dev libtirpc-dev ncurses-dev openssl-dev python3-dev py3-pip xz-dev" && \
    DBBACKUP_RUN_DEPS_ALPINE="bzip2 coreutils gpg gpg-agent groff libarchive libtirpc mariadb-client mariadb-connector-c mongodb-tools ncurses openssl pigz pixz postgresql18-client pv py3-botocore py3-colorama py3-cryptography py3-docutils py3-jmespath py3-rsa py3-setuptools py3-s3transfer py3-yaml python3 redis sqlite xz zip zstd" && \
    package update && \
    package upgrade && \
    package install DBBACKUP_BUILD_DEPS DBBACKUP_RUN_DEPS && \
    case "$(uname -m)" in \
        x86_64 ) \
            influx2_arch=amd64; \
            influx2_install=true; \
            mssql_arch=amd64; \
            mssql_install=true \
        ;; \
        arm64 | aarch64 ) \
            influx2_arch=arm64; \
            influx2_install=true; \
            mssql_arch=arm64; \
            mssql_install=true \
        ;; \
        * ) \
            influx2_arch=""; \
            influx2_install=false; \
            mssql_arch=""; \
            mssql_install=false \
        ;; \
    esac ; \
    if [ "${influx2_install}" = true ] ; then \
        curl -sSL \
            "https://dl.influxdata.com/influxdb/releases/influxdb2-client-${INFLUX2_CLIENT_VERSION}-linux-${influx2_arch}.tar.gz" \
            | tar xvfz - --strip=1 -C /usr/sbin/ ; \
        chmod +x /usr/sbin/influx ; \
    else \
        echo >&2 "Unable to install the InfluxDB 2 client on this architecture" ; \
    fi ; \
    if [ "${mssql_install}" = true ] ; then \
        mkdir -p /opt/microsoft/msodbcsql18/ && \
        touch /opt/microsoft/msodbcsql18/ACCEPT_EULA && \
        curl -sSL -O \
            "https://download.microsoft.com/download/9dcab408-e0d4-4571-a81a-5a0951e3445f/msodbcsql18_${MSODBC_VERSION}_${mssql_arch}.apk" && \
        curl -sSL -O \
            "https://download.microsoft.com/download/b60bb8b6-d398-4819-9950-2e30cf725fb0/mssql-tools18_${MSSQL_VERSION}_${mssql_arch}.apk" && \
        echo y | apk add --allow-untrusted \
            "msodbcsql18_${MSODBC_VERSION}_${mssql_arch}.apk" \
            "mssql-tools18_${MSSQL_VERSION}_${mssql_arch}.apk" && \
        rm -f \
            "msodbcsql18_${MSODBC_VERSION}_${mssql_arch}.apk" \
            "mssql-tools18_${MSSQL_VERSION}_${mssql_arch}.apk" ; \
    else \
        echo >&2 "Unable to install the MSSQL client on this architecture" ; \
    fi ; \
    clone_git_repo https://github.com/influxdata/influxdb "${INFLUX1_CLIENT_VERSION}" && \
    go build -o /usr/sbin/influxd ./cmd/influxd && \
    strip /usr/sbin/influxd && \
    clone_git_repo "${MYSQL_REPO_URL}" "${MYSQL_VERSION}" && \
    cmake \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DCMAKE_INSTALL_PREFIX=/opt/mysql \
        -DFORCE_INSOURCE_BUILD=1 \
        -DWITHOUT_SERVER:BOOL=ON && \
    make -j"$(nproc)" install && \
    pip3 install --break-system-packages "awscli==${AWS_CLI_VERSION}" && \
    pip3 install --break-system-packages blobxfer && \
    mkdir -p /usr/src/pbzip2 && \
    curl -sSL \
        https://launchpad.net/pbzip2/1.1/1.1.13/+download/pbzip2-1.1.13.tar.gz \
        | tar xvfz - --strip=1 -C /usr/src/pbzip2 && \
    cd /usr/src/pbzip2 && \
    make && \
    make install && \
    package remove DBBACKUP_BUILD_DEPS && \
    package cleanup && \
    rm -rf /root/.cache /root/go /tmp/* /usr/src/*

# The upstream runtime rootfs is copied after the package build. It is staged
# outside /usr/src because the upstream cleanup removes /usr/src/*.

# Temporary downstream patch for nfrastack/container-db-backup 4.9.0:
# Oracle MySQL clients reject --skip-ssl and require --ssl-mode=DISABLED.
RUN set -eux; \
    python3 - <<'PY'
from pathlib import Path
import re

path = Path("/build-context/db-rootfs/container/functions/10-dbbackup")
content = path.read_text()

pattern = re.compile(
    r'(?m)^(?P<indent>[ \t]*)mysql_tls_args="--skip-ssl"[ \t]*$'
)

matches = list(pattern.finditer(content))

if len(matches) != 1:
    raise RuntimeError(
        f"Expected exactly one mysql_tls_args --skip-ssl assignment, "
        f"found {len(matches)} in {path}"
    )

indent = matches[0].group("indent")

replacement = "\n".join([
    f'{indent}case "${{backup_job_mysql_client,,}}" in',
    f'{indent}    mariadb )',
    f'{indent}        mysql_tls_args="--skip-ssl"',
    f'{indent}    ;;',
    f'{indent}    mysql )',
    f'{indent}        mysql_tls_args="--ssl-mode=DISABLED"',
    f'{indent}    ;;',
    f'{indent}esac',
])

content, replacements = pattern.subn(replacement, content)

if replacements != 1:
    raise RuntimeError(f"Patch unexpectedly made {replacements} replacements")

path.write_text(content)
PY

RUN set -eux; \
    grep -F 'mysql_tls_args="--ssl-mode=DISABLED"' \
        /build-context/db-rootfs/container/functions/10-dbbackup; \
    grep -F 'mysql_tls_args="--skip-ssl"' \
        /build-context/db-rootfs/container/functions/10-dbbackup; \
    cp -a /build-context/db-rootfs/. /; \
    rm -rf /build-context


ENTRYPOINT ["/init"]
