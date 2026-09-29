# SkyFire 5.4.8 Container

Containerized deployment of [Project SkyFire 5.4.8](https://github.com/ProjectSkyfire/SkyFire_548), a World of Warcraft Mists of Pandaria server. Works with both Docker and Podman.

## Overview

This repository provides container images and compose files to run a complete SkyFire 5.4.8 server stack:

- **db** — MySQL 9.7 database server
- **db-init** — One-shot initializer that creates databases, imports base SQL, and applies updates
- **worldserver** — The main game world server
- **authserver** — Authentication/login server
- **extractors** — Optional client data extraction tools (compose profile)

Pre-built images are available on GitHub Container Registry:

- `ghcr.io/dr1s/skyfire548-server`
- `ghcr.io/dr1s/skyfire548-db-init`

## Requirements

- [Docker](https://docs.docker.com/) or [Podman](https://podman.io/)
- Docker Compose / Podman Compose
- A WoW 5.4.8 client (for data extraction)

## Quick start

1. Copy the example environment file and adjust it to your needs:

   ```bash
   cp .env.example .env
   ```

2. (Podman only) Rename the Podman override file so Compose picks it up automatically:

   ```bash
   cp container-compose.podman.override.yml container-compose.override.yml
   ```

   Docker users can skip this step.

3. Start the database and wait for the one-shot `db-init` service to complete:

   ```bash
   docker compose -f container-compose.yml up db-init
   ```

4. Start the auth and world servers:

   ```bash
   docker compose -f container-compose.yml up -d authserver worldserver
   ```

   On Podman/rootless setups the override file configures `userns_mode: keep-id` and the correct SELinux volume labels.

## Configuration

All configuration is done through environment variables in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `SKYFIRE_SERVER_IMAGE` | `localhost/dr1s/skyfire548-server:latest` | Image used for `worldserver`, `authserver`, and `extractors` |
| `SKYFIRE_DBINIT_IMAGE` | `localhost/dr1s/skyfire548-db-init:latest` | Image used for the `db-init` service |
| `DB_HOST` | `db` | Hostname of the database service |
| `DB_PORT` | `3306` | Database port |
| `DB_USER` | `skyfire` | Database user used by the server and created in MySQL |
| `DB_PASSWORD` | `skyfire` | Database password used by the server and set in MySQL |
| `DB_ROOT_PASSWORD` | `skyfire` | MySQL root password used by `db-init` |
| `DB_DATA_VOL` | `dbdata` | Volume/path for MySQL data |
| `CLIENT_DATA_VOL` | `./data` | Volume/path for client extracted data |

### Volumes

- `./etc` — Server configuration files (`worldserver.conf`, `authserver.conf`)
- `./data` — Extracted client data (maps, vmaps, mmaps, dbc, cameras, db2)
- `dbdata` — Persistent MySQL data
- `init-marker` — Tracks whether `db-init` has already run
- `client-data` — Persistent client data extracted from the WoW client

## Extracting client data

Use the optional `extractors` profile to extract data from a mounted WoW 5.4.8 client:

```bash
docker compose -f container-compose.yml --profile extractors run --rm extractors
```

Before running, uncomment and set the client mount in your override file (`container-compose.override.yml` on Podman, or create your own `container-compose.override.yml` on Docker):

```yaml
services:
  extractors:
    volumes:
      - /path/to/wow-548:/client:Z
```

## Building images locally

If you prefer to build the images yourself instead of using the pre-built GHCR images:

```bash
# Server image
docker build -t localhost/dr1s/skyfire548-server:latest -f server/Containerfile ./server

# Database initializer image
docker build -t localhost/dr1s/skyfire548-db-init:latest -f db-init/Containerfile ./db-init
```

## Upstream

This project packages the [SkyFire 5.4.8](https://github.com/ProjectSkyfire/SkyFire_548) emulator. All game logic and SQL content belongs to the SkyFire project and its contributors.
