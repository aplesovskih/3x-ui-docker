#!/bin/sh
set -e

echo "[nginx-entrypoint] Ожидание готовности 3x-ui..."

PANEL_PORT="${PANEL_PORT:-45212}"
MAX_WAIT=30
WAITED=0

while ! nc -z 3x-ui "$PANEL_PORT" 2>/dev/null; do
    WAITED=$((WAITED + 1))
    if [ "$WAITED" -ge "$MAX_WAIT" ]; then
        echo "[nginx-entrypoint] 3x-ui не отвечает на порту $PANEL_PORT за ${MAX_WAIT}с — запуск nginx без ожидания"
        break
    fi
    sleep 1
done

if [ "$WAITED" -lt "$MAX_WAIT" ]; then
    echo "[nginx-entrypoint] 3x-ui готов на порту $PANEL_PORT (ожидал ${WAITED}с)"
fi

exec "$@"
