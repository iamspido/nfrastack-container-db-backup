# nfrastack-container-db-backup

[![Build container](https://github.com/iamspido/nfrastack-container-db-backup/actions/workflows/build-container.yml/badge.svg)](https://github.com/iamspido/nfrastack-container-db-backup/actions/workflows/build-container.yml)
[![GHCR](https://img.shields.io/badge/GHCR-ghcr.io%2Fiamspido%2Fnfrastack--container--db--backup-blue)](https://github.com/iamspido/nfrastack-container-db-backup/pkgs/container/nfrastack-container-db-backup)
[![Platforms](https://img.shields.io/badge/platform-linux%2Famd64%20%7C%20linux%2Farm64-lightgrey)](#image-tags)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

Unofficial multi-architecture build of
[`nfrastack/container-db-backup`](https://github.com/nfrastack/container-db-backup),
published to GitHub Container Registry for AMD64 and ARM64.

> This project is not affiliated with or endorsed by Nfrastack.

## Why this image exists

The official prebuilt Nfrastack images are feature-limited. Nfrastack documents
that building `container-base` from source enables its advanced functionality.
The upstream database-backup image supports jobs named `DB01` through `DB99`,
but limits non-advanced builds to three configured jobs.

This repository therefore:

1. builds [`nfrastack/container-base`](https://github.com/nfrastack/container-base) from a pinned release tag;
2. builds `nfrastack/container-db-backup` from a pinned release tag on top of it;
3. publishes a single multi-architecture image for `linux/amd64` and `linux/arm64`.

No unlock code is required for this source-built image.

## Pull the image

```bash
docker pull ghcr.io/iamspido/nfrastack-container-db-backup:latest
```

## Docker Compose example

The following example configures four PostgreSQL backup jobs and stores the
resulting files under `./backups`:

```yaml
services:
  db-backup:
    image: ghcr.io/iamspido/nfrastack-container-db-backup:4.9.0
    container_name: db-backup
    restart: unless-stopped

    volumes:
      - ./backups:/backup
      - ./logs:/logs

    environment:
      TIMEZONE: Europe/Berlin

      DEFAULT_BACKUP_LOCATION: FILESYSTEM
      DEFAULT_FILESYSTEM_PATH: /backup
      DEFAULT_COMPRESSION: ZSTD
      DEFAULT_BACKUP_BEGIN: "0300"
      DEFAULT_BACKUP_INTERVAL: "1440"

      DB01_TYPE: pgsql
      DB01_HOST: postgres
      DB01_NAME: application_1
      DB01_USER: backup
      DB01_PASS: "${DB01_PASS}"

      DB02_TYPE: pgsql
      DB02_HOST: postgres
      DB02_NAME: application_2
      DB02_USER: backup
      DB02_PASS: "${DB02_PASS}"

      DB03_TYPE: pgsql
      DB03_HOST: postgres
      DB03_NAME: application_3
      DB03_USER: backup
      DB03_PASS: "${DB03_PASS}"

      DB04_TYPE: pgsql
      DB04_HOST: postgres
      DB04_NAME: application_4
      DB04_USER: backup
      DB04_PASS: "${DB04_PASS}"
```

Store the passwords in a local `.env` file and do not commit it:

```dotenv
DB01_PASS=change-me
DB02_PASS=change-me
DB03_PASS=change-me
DB04_PASS=change-me
```

Start the container:

```bash
docker compose up -d
docker compose logs -f db-backup
```

The database hosts must be reachable from the backup container, for example by
placing the services on the same Docker network.

## Manual backups and restore

Run all configured backup jobs:

```bash
docker compose exec db-backup backup-now
```

Run only job `DB04`:

```bash
docker compose exec db-backup backup04-now
```

Open the interactive restore utility:

```bash
docker compose exec db-backup restore
```

## Supported databases and storage targets

Database types supported by the upstream project include CouchDB, InfluxDB,
MariaDB/MySQL, Microsoft SQL Server, MongoDB, PostgreSQL, Redis and SQLite.
Backups can be written to the local filesystem, S3-compatible storage or Azure
Blob Storage.

For the complete configuration reference, scheduling options, encryption,
notifications, hooks and restore documentation, use the
[upstream README](https://github.com/nfrastack/container-db-backup/tree/4.9.0#readme).

## Image tags

| Tag | Description |
| --- | --- |
| `latest` | Current version pinned by this repository |
| `4.9.0` | Pinned `container-db-backup` release |
| `4.9.0-base-2026.7.0` | Pinned application and base releases |

Published platforms:

- `linux/amd64`
- `linux/arm64`

`latest` follows the versions pinned in this repository. It does not
automatically track new upstream releases.

## Build and release process

The versions are defined at the top of the `Dockerfile`:

```dockerfile
ARG CONTAINER_BASE_TAG=2026.7.0
ARG DB_BACKUP_TAG=4.9.0
```

The GitHub Actions workflow builds both architectures on native hosted runners,
pushes the architecture-specific images by digest and publishes a combined
multi-architecture manifest to:

```text
ghcr.io/iamspido/nfrastack-container-db-backup
```

A push to `main` that changes the `Dockerfile` or the workflow starts a new
build. The workflow can also be started manually from the repository's
**Actions** tab.

## Updating the upstream versions

1. Verify the new release tags in both upstream repositories.
2. Update `CONTAINER_BASE_TAG` and `DB_BACKUP_TAG` in the `Dockerfile`.
3. Update the version examples and tag table in this README.
4. Commit and push the changes.

Do not replace the pinned tags with `main`; release tags make builds more
predictable and reviewable.

## Support

Use this repository's issue tracker for problems with this Dockerfile, the
GitHub Actions workflow or the published GHCR image.

For application configuration and behavior, consult the upstream
[`container-db-backup` documentation](https://github.com/nfrastack/container-db-backup).
When reporting an upstream application bug, make it clear that the issue was
observed in an unofficial source build.

## License

The build files in this repository are licensed under the [MIT License](LICENSE).
The upstream projects are also MIT-licensed. Their copyright and license notices
are retained in the resulting container image.
