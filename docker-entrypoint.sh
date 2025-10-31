#!/bin/sh
set -e

DEFAULT_PUID=99
DEFAULT_PGID=100
DEFAULT_UMASK=002

PUID="${PUID:-$DEFAULT_PUID}"
PGID="${PGID:-$DEFAULT_PGID}"
UMASK="${UMASK:-$DEFAULT_UMASK}"

case "$PUID" in
  ''|*[!0-9]*) echo "ERROR: PUID must be a numeric value (got '$PUID')." >&2; exit 1 ;;
esac
case "$PGID" in
  ''|*[!0-9]*) echo "ERROR: PGID must be a numeric value (got '$PGID')." >&2; exit 1 ;;
esac
case "$UMASK" in
  ''|*[!0-7]*) echo "ERROR: UMASK must be an octal value (e.g. 002)." >&2; exit 1 ;;
esac

APP_USER=app
HOME_DIR=/home/app
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME_DIR}/.config}"
CONFIG_DIR="${CONFIG_HOME}/plexamp-tui"
AUTH_FILE="${CONFIG_DIR}/plex_auth.json"
PERMCHECK="${CONFIG_DIR}/.permcheck"

umask "$UMASK"

ensure_group() {
  local group_name lookup
  if getent group "$PGID" >/dev/null 2>&1; then
    lookup=$(getent group "$PGID" | cut -d: -f1)
    echo "$lookup"
    return
  fi

  group_name="$1"
  if getent group "$group_name" >/dev/null 2>&1; then
    delgroup "$group_name" >/dev/null 2>&1 || true
  fi
  addgroup -g "$PGID" "$group_name"
  echo "$group_name"
}

APP_GROUP="$(ensure_group app)"

if id "$APP_USER" >/dev/null 2>&1; then
  CURRENT_UID=$(id -u "$APP_USER")
  CURRENT_GID=$(id -g "$APP_USER")
  if [ "$CURRENT_UID" != "$PUID" ] || [ "$CURRENT_GID" != "$PGID" ]; then
    deluser "$APP_USER" >/dev/null 2>&1 || true
  fi
fi

if ! id "$APP_USER" >/dev/null 2>&1; then
  adduser -D -h "$HOME_DIR" -u "$PUID" -G "$APP_GROUP" -s /sbin/nologin "$APP_USER"
fi

addgroup "$APP_USER" "$APP_GROUP" >/dev/null 2>&1 || true
mkdir -p "$HOME_DIR" "$CONFIG_DIR"
chown -R "$APP_USER:$APP_GROUP" "$HOME_DIR" >/dev/null 2>&1 || true
chown "$APP_USER:$APP_GROUP" "$CONFIG_DIR" >/dev/null 2>&1 || true

if ! su-exec "$APP_USER:$APP_GROUP" sh -c "mkdir -p '$CONFIG_DIR' && touch '$PERMCHECK' && rm -f '$PERMCHECK'"; then
  echo "ERROR: Unable to write to ${CONFIG_DIR}. Ensure the directory is writable by UID ${PUID} and GID ${PGID}." >&2
  exit 1
fi

run_plexamp() {
  if [ "$#" -gt 0 ]; then
    case "$1" in
      --help|-help|-h|help)
        exec su-exec "$APP_USER:$APP_GROUP" plexamp-tui "$@"
        ;;
    esac
  fi

  if ! su-exec "$APP_USER:$APP_GROUP" sh -c "[ -f '$AUTH_FILE' ]"; then
    if ! printf '%s\0' "$@" | grep -q -- '--auth'; then
      echo "plexamp-tui: no plex_auth.json detected, starting authentication flow..."
      su-exec "$APP_USER:$APP_GROUP" plexamp-tui --auth
    fi
  fi
  exec su-exec "$APP_USER:$APP_GROUP" plexamp-tui "$@"
}

if [ "$#" -eq 0 ]; then
  run_plexamp
fi

if [ "$1" = "plexamp-tui" ]; then
  shift
  run_plexamp "$@"
fi

exec su-exec "$APP_USER:$APP_GROUP" "$@"
