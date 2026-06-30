#!/bin/sh

set -e;

CONF_PATH_PARAM="";

if [ "${EBK_CONF_PATH}" != "" ]; then
  CONF_PATH_PARAM="--conf-path=${EBK_CONF_PATH}";
fi

# If a sub-command is passed, run it directly
if [ $# -gt 0 ]; then
    exec "$@"
fi

# --- Litestream integration ---
LITESTREAM_DB_PATH="${LITESTREAM_DB_PATH:-/ezbookkeeping/data/ezbookkeeping.db}"
LITESTREAM_REPLICA_URL="${LITESTREAM_REPLICA_URL}"
LITESTREAM_ACCESS_KEY_ID="${LITESTREAM_ACCESS_KEY_ID}"
LITESTREAM_SECRET_ACCESS_KEY="${LITESTREAM_SECRET_ACCESS_KEY}"
LITESTREAM_REGION="${LITESTREAM_REGION:-auto}"
LITESTREAM_ENDPOINT="${LITESTREAM_ENDPOINT}"
LITESTREAM_RESTORE_IF_DB_MISSING="${LITESTREAM_RESTORE_IF_DB_MISSING:-true}"

LITESTREAM_CONFIG_PATH="${LITESTREAM_CONFIG_PATH:-/ezbookkeeping/litestream.yml}"

if [ -n "${LITESTREAM_REPLICA_URL}" ]; then
  echo "Setting up litestream replication..."

  cat > "${LITESTREAM_CONFIG_PATH}" <<-EOCFG
dbs:
  - path: ${LITESTREAM_DB_PATH}
    replicas:
      - url: ${LITESTREAM_REPLICA_URL}
EOCFG

  if [ -n "${LITESTREAM_ACCESS_KEY_ID}" ]; then
    echo "        access-key-id: ${LITESTREAM_ACCESS_KEY_ID}" >> "${LITESTREAM_CONFIG_PATH}"
  fi

  if [ -n "${LITESTREAM_SECRET_ACCESS_KEY}" ]; then
    echo "        secret-access-key: ${LITESTREAM_SECRET_ACCESS_KEY}" >> "${LITESTREAM_CONFIG_PATH}"
  fi

  if [ -n "${LITESTREAM_REGION}" ]; then
    echo "        region: ${LITESTREAM_REGION}" >> "${LITESTREAM_CONFIG_PATH}"
  fi

  if [ -n "${LITESTREAM_ENDPOINT}" ]; then
    echo "        endpoint: ${LITESTREAM_ENDPOINT}" >> "${LITESTREAM_CONFIG_PATH}"
  fi

  # Restore from replica if local DB missing
  if [ "${LITESTREAM_RESTORE_IF_DB_MISSING}" = "true" ] && [ ! -f "${LITESTREAM_DB_PATH}" ]; then
    echo "Local database not found. Attempting restore from litestream replica..."
    litestream restore \
      -if-db-not-exists \
      -if-replica-exists \
      -config "${LITESTREAM_CONFIG_PATH}" \
      "${LITESTREAM_DB_PATH}" \
      && echo "Restore successful." \
      || echo "No existing replica found. A new database will be created."
  fi

  # Start litestream replication in background
  echo "Starting litestream replication..."
  litestream replicate -config "${LITESTREAM_CONFIG_PATH}" &
fi

# Start ezbookkeeping
exec /ezbookkeeping/ezbookkeeping server run ${CONF_PATH_PARAM};
