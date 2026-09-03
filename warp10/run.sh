#!/usr/bin/env bash
set -e

OPTIONS_FILE="/data/options.json"
TOKENS_CONF="/data/tokens.conf"
OWNER_UUID_FILE="/data/.ha_token_owner_uuid"
ISSUANCE_FILE="/data/.ha_token_issuance_ms"
EXT_CONFIG_DIR="/config.extra"
TOKEN_TTL_MS=$((20 * 365 * 24 * 60 * 60 * 1000))  # 20 years

if [ -f "$OPTIONS_FILE" ]; then
    HEAP=$(jq -r '.heap // "1g"' "$OPTIONS_FILE")
    DISABLE_SENSISION=$(jq -r '.disable_sensision // false' "$OPTIONS_FILE")
    WRITE_TOKEN=$(jq -r '.write_token // ""' "$OPTIONS_FILE")
    READ_TOKEN=$(jq -r '.read_token // ""' "$OPTIONS_FILE")
else
    HEAP="1g"
    DISABLE_SENSISION="false"
    WRITE_TOKEN=""
    READ_TOKEN=""
fi

export WARP10_HEAP="$HEAP"
export WARP10_HEAP_MAX="$HEAP"

if [ "$DISABLE_SENSISION" = "true" ]; then
    export NO_SENSISION=true
fi

echo "[warp10-addon] heap=${WARP10_HEAP} sensision_disabled=${DISABLE_SENSISION}"

# --- Named tokens via Warp10's `warp.token.file` ----------------------------
#
# Warp10 supports a plaintext token file (config property `warp.token.file`)
# that a background thread re-reads every 60s. We use the `token.spec = { ... }`
# line form (a WarpScript map, same shape TOKENGEN's own envelopes use, parsed
# via TOKENGEN.tokenFromMap) rather than the terser `token.write.<id>.*`
# key=value form: that shorter form silently defaults issuance to epoch-0 and
# expiry to Long.MAX_VALUE when omitted (see Tokens.java's loadTokens/sanitize
# pass) and has no way to set issuance at all. Spelling out 'issuance'/'ttl',
# and 'labels'/'attributes' (empty maps where unused), explicitly here is more
# auditable than relying on that implicit fallback.
#
# The read token's 'attributes' sets the '.cap:maxops'/'.cap:maxdepth'
# capabilities, capping the WarpScript ops and stack depth any script run
# with that token may use (1e7/1e5) — a sane ceiling for a token that may end
# up in something like a Grafana datasource. Values must be strings, hence
# the `1e7 TOLONG TOSTRING` (avoids the double's default "1.0E7" formatting).
#
# Owner/producer UUID and the issuance timestamp are each generated once and
# persisted under /data, since Warp10 indexes stored GTS by the owner/producer
# UUID baked into the write token used — if that UUID changed across restarts,
# previously written data would become unreadable even though it's still on
# disk. The token strings themselves (further down) are persisted the same way.
if [ ! -f "$OWNER_UUID_FILE" ]; then
    cat /proc/sys/kernel/random/uuid > "$OWNER_UUID_FILE"
fi
OWNER_UUID=$(cat "$OWNER_UUID_FILE")

if [ ! -f "$ISSUANCE_FILE" ]; then
    echo $(( $(date +%s) * 1000 )) > "$ISSUANCE_FILE"
fi
ISSUANCE_MS=$(cat "$ISSUANCE_FILE")

if [ -z "$WRITE_TOKEN" ]; then
    DEFAULT_WRITE_TOKEN_FILE="/data/.ha_default_write_token"
    if [ ! -f "$DEFAULT_WRITE_TOKEN_FILE" ]; then
        echo "ha-write-$(cat /proc/sys/kernel/random/uuid)" > "$DEFAULT_WRITE_TOKEN_FILE"
    fi
    WRITE_TOKEN=$(cat "$DEFAULT_WRITE_TOKEN_FILE")
fi

if [ -z "$READ_TOKEN" ]; then
    DEFAULT_READ_TOKEN_FILE="/data/.ha_default_read_token"
    if [ ! -f "$DEFAULT_READ_TOKEN_FILE" ]; then
        echo "ha-read-$(cat /proc/sys/kernel/random/uuid)" > "$DEFAULT_READ_TOKEN_FILE"
    fi
    READ_TOKEN=$(cat "$DEFAULT_READ_TOKEN_FILE")
fi

cat > "$TOKENS_CONF" <<EOF
token.spec = { 'id' '${WRITE_TOKEN}' 'type' 'WRITE' 'application' 'homeassistant' 'owner' '${OWNER_UUID}' 'producer' '${OWNER_UUID}' 'issuance' ${ISSUANCE_MS} 'ttl' ${TOKEN_TTL_MS} 'labels' { } 'attributes' { } }
token.spec = { 'id' '${READ_TOKEN}' 'type' 'READ' 'application' 'homeassistant' 'owner' '${OWNER_UUID}' 'issuance' ${ISSUANCE_MS} 'ttl' ${TOKEN_TTL_MS} 'owners' [ '${OWNER_UUID}' ] 'producers' [ '${OWNER_UUID}' ] 'applications' [ 'homeassistant' ] 'labels' { } 'attributes' { '.cap:maxops' 1e7 TOLONG TOSTRING '.cap:maxdepth' 1e5 TOLONG TOSTRING } }
EOF
chmod 644 "$TOKENS_CONF"

# Warp10 only requires this directory to exist and to contain *.conf files;
# it's scanned fresh on every start (see warp10.sh's WARP10_EXT_CONFIG_DIR
# handling), so this doesn't depend on the base image's first-run init.
mkdir -p "$EXT_CONFIG_DIR"
echo "warp.token.file = ${TOKENS_CONF}" > "${EXT_CONFIG_DIR}/10-ha-token-file.conf"
chmod 644 "${EXT_CONFIG_DIR}/10-ha-token-file.conf"

echo "[warp10-addon] write token: ${WRITE_TOKEN}"
echo "[warp10-addon] read token:  ${READ_TOKEN}"
echo "[warp10-addon] (use the write token when configuring warp10-ha-integration)"

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
