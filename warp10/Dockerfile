# Pin the upstream Warp10 release baked into this add-on. Overridden at
# build time via --build-arg from the CI workflow.
#
# NOTE: warp10io/warp10 has never published a bare "<version>" tag; since
# 3.0.0 it's always "<version>-ubuntu" or "<version>-alpine" (each with a
# "-ci" test variant too). We use "-ubuntu" since that's the flavor whose
# docker-entrypoint.sh / BUILD_WARPSTUDIO env var run.sh relies on. Verify
# the tag actually exists before bumping:
# https://hub.docker.com/r/warp10io/warp10/tags
ARG WARP10_VERSION=3.5.0-ubuntu
FROM warp10io/warp10:${WARP10_VERSION}

# ARGs declared before FROM don't survive it; redeclare the ones injected
# automatically by the home-assistant/builder build-image action.
ARG BUILD_ARCH
ARG BUILD_VERSION

# jq is used by run.sh to read Home Assistant's /data/options.json
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
RUN chmod a+x /run.sh

# We deliberately do NOT replace the base image's own start-up logic:
# run.sh translates HA add-on options into the env vars the upstream
# image already understands (WARP10_HEAP, NO_SENSISION, ...), then execs
# the original entrypoint so the rest of its init (token generation,
# permission fixup, JVM launch) runs unmodified.
ENTRYPOINT [ "/run.sh" ]

# Docker resets an inherited CMD to empty as soon as a derived Dockerfile
# sets its own ENTRYPOINT (see "Understand how CMD and ENTRYPOINT interact"
# in Docker's docs) — without redeclaring it here, run.sh's "$@" is empty,
# which propagates all the way to docker-entrypoint.sh's final
# `exec gosu warp10 "$@"`, so gosu gets no command and just prints its
# usage banner instead of ever launching the JVM. Must match the base
# image's own CMD exactly (senx/warp10-docker's ubuntu/Dockerfile).
CMD [ "/opt/warp10/bin/warp10.sh", "start" ]
