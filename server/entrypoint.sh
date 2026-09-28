#!/usr/bin/env bash
set -euo pipefail

SKYFIRE_HOME="${SKYFIRE_HOME:-/opt/skyfire-server}"

DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-skyfire}"
DB_PASSWORD="${DB_PASSWORD:-skyfire}"
DB_LOGIN="${DB_LOGIN:-auth}"
DB_WORLD="${DB_WORLD:-world}"
DB_CHAR="${DB_CHAR:-characters}"

DB_INFO() {
  local db="$1"
  printf '%s;%s;%s;%s;%s' "${DB_HOST}" "${DB_PORT}" "${DB_USER}" "${DB_PASSWORD}" "${db}"
}

set_conf() {
  local file="$1" key="$2" value="$3"
  if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "${SKYFIRE_HOME}/etc/${file}"; then
    sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "${SKYFIRE_HOME}/etc/${file}"
  else
    printf '\n%s = %s\n' "${key}" "${value}" >> "${SKYFIRE_HOME}/etc/${file}"
  fi
}

ensure_conf() {
  local conf="$1"
  if [[ ! -f "${SKYFIRE_HOME}/etc/${conf}" ]]; then
    if [[ ! -f "${SKYFIRE_HOME}/etc.dist/${conf}.dist" ]]; then
      echo "Missing config template: ${conf}.dist" >&2
      exit 1
    fi
    cp "${SKYFIRE_HOME}/etc.dist/${conf}.dist" "${SKYFIRE_HOME}/etc/${conf}"
  fi
}


ROLE="${1:-worldserver}"
shift || true

case "${ROLE}" in
  authserver)
    ensure_conf authserver.conf
    set_conf "authserver.conf" "LoginDatabaseInfo" "\"$(DB_INFO "${DB_LOGIN}")\""
    echo "Starting authserver..."
    exec "${SKYFIRE_HOME}/bin/authserver" -c "${SKYFIRE_HOME}/etc/authserver.conf" "$@"
    ;;
  worldserver)
    ensure_conf worldserver.conf
    set_conf "worldserver.conf" "LoginDatabaseInfo" "\"$(DB_INFO "${DB_LOGIN}")\""
    set_conf "worldserver.conf" "WorldDatabaseInfo" "\"$(DB_INFO "${DB_WORLD}")\""
    set_conf "worldserver.conf" "CharacterDatabaseInfo" "\"$(DB_INFO "${DB_CHAR}")\""

    RUN_DIR="${SKYFIRE_HOME}/run"
    FIFO="${WORLDSERVER_FIFO:-${RUN_DIR}/skyfire.in}"
    mkdir -p "$(dirname "${FIFO}")"
    rm -f "${FIFO}"
    echo "Starting worldserver (console FIFO: ${FIFO})..."
    exec bash -c '
      set -euo pipefail
      FIFO="$1"
      SKYFIRE_HOME="$2"
      shift 2
      mkfifo "${FIFO}"
      exec 3<>"${FIFO}"
      exec "${SKYFIRE_HOME}/bin/worldserver" -c "${SKYFIRE_HOME}/etc/worldserver.conf" "$@" <&3
    ' bash "${FIFO}" "${SKYFIRE_HOME}" "$@"
    ;;
  extractors)
      cd /client

      echo "Extracting maps..."
      "${SKYFIRE_HOME}/bin/mapextractor"
      echo "Extracting vmap4..."
      "${SKYFIRE_HOME}/bin/vmap4extractor"
      echo "Assembling vmap4..."
      "${SKYFIRE_HOME}/bin/vmap4assembler" Buildings vmaps
      echo "Generating mmaps..."
      "${SKYFIRE_HOME}/bin/mmaps_generator"

      echo "Syncing maps..."
      mv maps dbc vmaps mmaps cameras db2 "${SKYFIRE_HOME}/data"
      echo "Maps extracted successfully."
    ;;
  bash)
    exec bash "$@"
    ;;
  sh)
    exec sh "$@"
    ;;
  *)
    echo "Unknown role: ${ROLE}" >&2
    echo "Usage: entrypoint.sh {db-init|authserver|worldserver|extractors|bash|sh}" >&2
    exit 1
    ;;
esac
