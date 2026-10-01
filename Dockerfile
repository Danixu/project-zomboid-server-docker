###########################################################
# Dockerfile that builds a Project Zomboid Gameserver
###########################################################
FROM cm2network/steamcmd:root

LABEL maintainer="daniel.carrasco@electrosoftcloud.com"

ENV STEAMAPPID=380870
ENV STEAMAPP=pz
ENV STEAMAPPDIR="${HOMEDIR}/${STEAMAPP}-dedicated"
# Fix for a new installation problem in the Steamcmd client
ENV HOME="${HOMEDIR}"

# Receive the value from docker-compose as an ARG
ARG STEAMAPPBRANCH="public"
# Promote the ARG value to an ENV for runtime
ENV STEAMAPPBRANCH=$STEAMAPPBRANCH

# Install required packages
RUN apt-get update \
  && apt-get install -y --no-install-recommends --no-install-suggests \
  dos2unix \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Generate locales to allow other languages in the PZ Server.
# The base image already generates en_US.UTF-8. Any other locale you want to be able to
# select through the LANG variable has to be generated here, so list them (space
# separated) in this argument.
ARG EXTRA_LOCALES="es_ES.UTF-8"
RUN for extra_locale in ${EXTRA_LOCALES}; do \
      sed -i "s/^# *\(${extra_locale}\)/\1/" /etc/locale.gen; \
    done \
  # Generate locale
  && locale-gen

# Download the Project Zomboid dedicated server app using the steamcmd app.
# SteamCMD sometimes fails on the first attempt with "Missing configuration"
# (exit code 8) until the app info is cached, and succeeds when run again, so
# the download is retried a few times before failing the build.
RUN set -x \
  && mkdir -p "${STEAMAPPDIR}" \
  && chown -R "${USER}:${USER}" "${STEAMAPPDIR}" \
  && if [ "${STEAMAPPBRANCH}" = "public" ]; then BETA_ARGS=""; \
     else BETA_ARGS="-beta ${STEAMAPPBRANCH}"; fi \
  && for attempt in 1 2 3; do \
       bash "${STEAMCMDDIR}/steamcmd.sh" +force_install_dir "${STEAMAPPDIR}" \
         +login anonymous \
         +app_update "${STEAMAPPID}" ${BETA_ARGS} validate \
         +quit \
       && break; \
       if [ "${attempt}" = "3" ]; then exit 1; fi; \
       echo "steamcmd failed (attempt ${attempt}), retrying in 10s..."; \
       sleep 10; \
     done

# Copy the entry point file
COPY --chown=${USER}:${USER} scripts/entry.sh /server/scripts/entry.sh
RUN chmod 550 /server/scripts/entry.sh

# Copy searchfolder file
COPY --chown=${USER}:${USER} scripts/search_folder.sh /server/scripts/search_folder.sh
RUN chmod 550 /server/scripts/search_folder.sh

# Create required folders to keep their permissions on mount
RUN mkdir -p "${HOMEDIR}/Zomboid"

WORKDIR ${HOMEDIR}
# Expose ports
EXPOSE 16261-16262/udp \
  27015/tcp

ENTRYPOINT ["/server/scripts/entry.sh"]