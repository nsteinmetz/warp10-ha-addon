#!/usr/bin/env bash
set -e

OPTIONS_FILE="/data/options.json"

if [ -f "$OPTIONS_FILE" ]; then
    HEAP=$(jq -r '.heap // "1g"' "$OPTIONS_FILE")
    DISABLE_SENSISION=$(jq -r '.disable_sensision // false' "$OPTIONS_FILE")
else
    HEAP="1g"
    DISABLE_SENSISION="false"
fi

export WARP10_HEAP="$HEAP"
export WARP10_HEAP_MAX="$HEAP"

if [ "$DISABLE_SENSISION" = "true" ]; then
    export NO_SENSISION=true
fi

echo "[warp10-addon] heap=${WARP10_HEAP} sensision_disabled=${DISABLE_SENSISION}"

# Hand off to the base image's own entrypoint, preserving whatever CMD
# it defines (passed through here as "$@"). This is where the upstream
# image does its first-run token generation, permission fixup, and
# finally launches the JVM.
#
# NOTE: /docker-entrypoint.sh is where the senx/warp10-docker Dockerfile
# has historically placed it. If you bump WARP10_VERSION and the add-on
# fails to start, confirm the path still matches with:
#   docker run --rm --entrypoint sh warp10io/warp10:<tag> -c 'ls -la /*.sh'
exec /docker-entrypoint.sh "$@"
