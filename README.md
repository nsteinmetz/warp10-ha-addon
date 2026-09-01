# Warp 10 Home Assistant add-on

Runs [Warp 10](https://www.warp10.io/) locally as a Home Assistant Supervisor
add-on, wrapping the official [`warp10io/warp10`](https://hub.docker.com/r/warp10io/warp10)
image. Pair it with the
[warp10-ha-integration](https://github.com/nsteinmetz/warp10-ha-integration)
custom integration to stream sensor data into it.

## Installation

1. Home Assistant → Settings → Add-ons → Add-on Store → ⋮ → **Repositories**.
2. Add this repository's URL:
   `https://github.com/nsteinmetz/warp10-ha-addon`
3. Find "Warp 10" in the store, install, then start it.

## Configuration

- **heap** — initial/max JVM heap size (default `1g`). Raise this if you
  ingest many sensors or keep long history.
- **disable_sensision** — disable Warp10's built-in usage-metrics
  collector (default `false`).

## Ports

- `8080` — Warp 10 HTTP API (`/api/v0/update`, `/api/v0/exec`, ...) — this
  is the URL you'll enter in the warp10-ha-integration config flow, e.g.
  `http://<home-assistant-ip>:8080` (or `http://<addon-hostname>:8080`
  using the Supervisor's internal DNS if calling from another add-on).
- `8081` — WarpStudio web UI.

## Data persistence

Warp10's storage lives under the add-on's own `/data` directory, which
Supervisor persists automatically across restarts and updates — no
additional volume mapping is needed.

## Generating a write token

Exec into the running add-on container (Settings → Add-ons → Warp 10 →
Terminal, if you have the SSH/Terminal add-on, or `docker exec` from the
host) and follow Warp10's standard
[token generation](https://www.warp10.io/content/03_Documentation/05_Security/03_Token_Management)
flow with `warp10.sh tokengen`. Use the resulting WRITE token when
configuring the warp10-ha-integration.

## Known caveats / things to verify before relying on this in production

- **Architectures**: `config.yaml` only lists `amd64` and `aarch64`.
  Confirm the `WARP10_VERSION` you pin in the build workflow actually
  publishes those architectures on
  [Docker Hub](https://hub.docker.com/r/warp10io/warp10/tags) before
  adding more (e.g. `armv7`).
- **Entrypoint path**: `run.sh` assumes the upstream image's entrypoint
  lives at `/docker-entrypoint.sh` (true as of the `senx/warp10-docker`
  repository at the time this was written). If a future Warp10 image
  restructures its startup script, `run.sh` will need updating — check
  with `docker run --rm --entrypoint sh warp10io/warp10:<tag> -c 'ls -la /*.sh'`
  after bumping `WARP10_VERSION`.
- This add-on has not been submitted to the official Home Assistant
  add-on store; it's meant to be added as a custom repository.

## License

Apache-2.0
