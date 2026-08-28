#!/bin/bash

cd ${STEAMAPPDIR}

#####################################
#                                   #
# Force an update if the env is set #
#                                   #
#####################################

if [ "${FORCESTEAMCLIENTSOUPDATE}" == "1" ] || [ "${FORCESTEAMCLIENTSOUPDATE,,}" == "true" ]; then
  echo "FORCESTEAMCLIENTSOUPDATE variable is set, updating steamclient.so in Zomboid's server"
  cp "${STEAMCMDDIR}/linux64/steamclient.so" "${STEAMAPPDIR}/linux64/steamclient.so"
  cp "${STEAMCMDDIR}/linux32/steamclient.so" "${STEAMAPPDIR}/steamclient.so"
fi

if [ "${FORCEUPDATE}" == "1" ] || [ "${FORCEUPDATE,,}" == "true" ]; then
  echo "FORCEUPDATE variable is set, so the server will be updated right now"
  # The public branch is not a beta: passing `-beta public` makes SteamCMD look for a
  # non existent beta, so the update silently does nothing and the server keeps running
  # the version baked into the image. This is the same condition the Dockerfile uses at
  # build time.
  if [ -z "${STEAMAPPBRANCH}" ] || [ "${STEAMAPPBRANCH}" == "public" ]; then
    STEAMAPPBRANCH_ARGS=()
  else
    STEAMAPPBRANCH_ARGS=(-beta "${STEAMAPPBRANCH}")
  fi
  bash "${STEAMCMDDIR}/steamcmd.sh" +force_install_dir "${STEAMAPPDIR}" +login anonymous +app_update "${STEAMAPPID}" "${STEAMAPPBRANCH_ARGS[@]}" validate +quit
fi


######################################
#                                    #
# Process the arguments in variables #
#                                    #
######################################
ARGS=""

# Set the server memory. Units are accepted (1024m=1Gig, 2048m=2Gig, 4096m=4Gig): Example: 1024m
if [ -n "${MIN_MEMORY}" ] && [ -n "${MAX_MEMORY}" ]; then
  ARGS="${ARGS} -Xms${MIN_MEMORY} -Xmx${MAX_MEMORY}"
elif [ -n "${MEMORY}" ]; then
  ARGS="${ARGS} -Xms${MEMORY} -Xmx${MEMORY}"
fi

# Option to perform a Soft Reset
if [ "${SOFTRESET}" == "1" ] || [ "${SOFTRESET,,}" == "true" ]; then
  ARGS="${ARGS} -Dsoftreset"
fi

# End of Java arguments
ARGS="${ARGS} -- "

# Runs a coop server instead of a dedicated server. Disables the default admin from being accessible.
# - Default: Disabled
if [ "${COOP}" == "1" ] || [ "${COOP,,}" == "true" ]; then
  ARGS="${ARGS} -coop"
fi

# Disables Steam integration on server.
# - Default: Enabled
if [ "${NOSTEAM}" == "1" ] || [ "${NOSTEAM,,}" == "true" ]; then
  ARGS="${ARGS} -nosteam"
fi

# Sets the path for the game data cache dir.
# - Default: ~/Zomboid
# - Example: /server/Zomboid/data
if [ -n "${CACHEDIR}" ]; then
  ARGS="${ARGS} -cachedir=${CACHEDIR}"
fi

# Option to control where mods are loaded from and the order. Any of the 3 keywords may be left out and may appear in any order.
# - Default: workshop,steam,mods
# - Example: mods,steam
if [ -n "${MODFOLDERS}" ]; then
  ARGS="${ARGS} -modfolders ${MODFOLDERS}"
fi

# Launches the game in debug mode.
# - Default: Disabled
if [ "${DEBUG}" == "1" ] || [ "${DEBUG,,}" == "true" ]; then
  ARGS="${ARGS} -debug"
fi

# Option to set the admin username. Current admins will not be changed.
if [ -n "${ADMINUSERNAME}" ]; then
  ARGS="${ARGS} -adminusername ${ADMINUSERNAME}"
fi

# Option to bypasses the enter-a-password prompt when creating a server.
# This option is mandatory the first startup or will be asked in console and startup will fail.
# Once is launched and data is created, then can be removed without problem.
# Is recommended to remove it, because the server logs the arguments in clear text, so Admin password will be sent to log in every startup.
if [ -n "${ADMINPASSWORD}" ]; then
  ARGS="${ARGS} -adminpassword ${ADMINPASSWORD}"
fi

# Server password (Doesn't work)
#if [ -n "${PASSWORD}" ]; then
#  ARGS="${ARGS} -password ${PASSWORD}"
#fi

# You can choose a different servername by using this option when starting the server.
if [ -n "${SERVERNAME}" ]; then
  ARGS="${ARGS} -servername \"${SERVERNAME}\""
else
  # If not servername is set, use the default name in the next step
  SERVERNAME="servertest"
fi

# If preset is set, then the config file is generated when it doesn't exists or SERVERPRESETREPLACE is set to True.
if [ -n "${SERVERPRESET}" ]; then
  # If preset file doesn't exists then show an error and exit
  if [ ! -f "${STEAMAPPDIR}/media/lua/shared/Sandbox/${SERVERPRESET}.lua" ]; then
    echo "*** ERROR: the preset ${SERVERPRESET} doesn't exists. Please fix the configuration before start the server ***"
    exit 1
  # If SandboxVars files doesn't exists or replace is true, copy the file
  elif [ ! -f "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_SandboxVars.lua" ] || [ "${SERVERPRESETREPLACE,,}" == "true" ]; then
    echo "*** INFO: New server will be created using the preset ${SERVERPRESET} ***"
    echo "*** Copying preset file from \"${STEAMAPPDIR}/media/lua/shared/Sandbox/${SERVERPRESET}.lua\" to \"${HOMEDIR}/Zomboid/Server/${SERVERNAME}_SandboxVars.lua\" ***"
    mkdir -p "${HOMEDIR}/Zomboid/Server/"
    cp -nf "${STEAMAPPDIR}/media/lua/shared/Sandbox/${SERVERPRESET}.lua" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_SandboxVars.lua"
    sed -i "1s/return.*/SandboxVars = \{/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_SandboxVars.lua"
    # Remove carriage return
    dos2unix "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_SandboxVars.lua"
    # I have seen that the file is created in execution mode (755). Change the file mode for security reasons.
    chmod 644 "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_SandboxVars.lua"
  fi
fi

# Option to handle multiple network cards. Example: 127.0.0.1
if [ -n "${IP}" ]; then
  ARGS="${ARGS} ${IP} -ip ${IP}"
fi

# Set the DefaultPort for the server. Example: 16261
if [ -n "${PORT}" ]; then
  ARGS="${ARGS} -port ${PORT}"
fi

# Option to enable/disable VAC on Steam servers. On the server command-line use -steamvac true/false. In the server's INI file, use STEAMVAC=true/false.
if [ -n "${STEAMVAC}" ] && { [ "${STEAMVAC,,}" == "true" ] || [ "${STEAMVAC,,}" == "false" ]; }; then
  ARGS="${ARGS} -steamvac ${STEAMVAC,,}"
fi

# Steam servers require two additional ports to function (I'm guessing they are both UDP ports, but you may need TCP as well).
# These are in addition to the DefaultPort= setting. These can be specified in two ways:
#  - In the server's INI file as SteamPort1= and SteamPort2=.
#  - Using STEAMPORT1 and STEAMPORT2 variables.
if [ -n "${STEAMPORT1}" ]; then
  ARGS="${ARGS} -steamport1 ${STEAMPORT1}"
fi
if [ -n "${STEAMPORT2}" ]; then
  ARGS="${ARGS} -steamport2 ${STEAMPORT2}"
fi

#############################################
#                                           #
# Server INI file settings                  #
#                                           #
#############################################

# The settings below live in the server INI file, which the server only creates on its
# first boot. Previously the sed commands silently did nothing on a fresh server (the
# file didn't exist yet), so these variables required a manual restart to take effect.
# Pre-creating an empty INI file fixes that: the server loads it on first boot, keeps
# the options set here and fills in every missing option with its default value.
SERVERINI="${HOMEDIR}/Zomboid/Server/${SERVERNAME}.ini"
if [ ! -f "${SERVERINI}" ]; then
  mkdir -p "${HOMEDIR}/Zomboid/Server/"
  touch "${SERVERINI}"
fi

# Set an option in the server INI file: replace it when present, append it when missing.
set_ini_option() {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" "${SERVERINI}"; then
    value=$(printf '%s' "$value" | sed 's/[&|\\]/\\&/g')
    sed -i "s|^${key}=.*|${key}=${value}|" "${SERVERINI}"
  else
    printf '%s=%s\n' "$key" "$value" >> "${SERVERINI}"
  fi
}

if [ -n "${PASSWORD}" ]; then
  set_ini_option "Password" "${PASSWORD}"
fi

if [ -n "${RCONPASSWORD}" ]; then
  set_ini_option "RCONPassword" "${RCONPASSWORD}"
fi

# Shows the server on the in-game browser.
if [ "${PUBLIC}" == "1" ] || [ "${PUBLIC,,}" == "true" ]; then
  set_ini_option "Public" "true"
elif [ "${PUBLIC}" == "0" ] || [ "${PUBLIC,,}" == "false" ]; then
  set_ini_option "Public" "false"
fi

# Set the display name for the server.
if [ -n "${DISPLAYNAME}" ]; then
  set_ini_option "PublicName" "${DISPLAYNAME}"
fi

# Set the second UDP port used for direct connections (UDPPort INI setting, by default 16262).
# There is no command line argument for this port, so it can only be set through the INI file.
if [ -n "${UDPPORT}" ]; then
  set_ini_option "UDPPort" "${UDPPORT}"
fi

if [ "${SELF_MANAGED_MODS}" == "1" ] || [ "${SELF_MANAGED_MODS,,}" == "true" ]; then
  echo "*** INFO: SELF_MANAGED_MODS is set; leaving Mods and WorkshopItems untouched ***"
else
  if [ -n "${MOD_IDS}" ]; then
    echo "*** INFO: Found Mods including ${MOD_IDS} ***"
    set_ini_option "Mods" "${MOD_IDS}"
  fi

  if [ -n "${WORKSHOP_IDS}" ]; then
    echo "*** INFO: Found Workshop IDs including ${WORKSHOP_IDS} ***"
    set_ini_option "WorkshopItems" "${WORKSHOP_IDS}"
  else
    echo "*** INFO: Workshop IDs is empty, clearing configuration ***"
    set_ini_option "WorkshopItems" ""
  fi
fi

# Fixes EOL in script file for good measure
sed -i 's/\r$//' /server/scripts/search_folder.sh
# Check 'search_folder.sh' script for details
if [ -e "${HOMEDIR}/pz-dedicated/steamapps/workshop/content/108600" ]; then

  map_list=""
  source /server/scripts/search_folder.sh "${HOMEDIR}/pz-dedicated/steamapps/workshop/content/108600"
  map_list=$(<"${HOMEDIR}/maps.txt")  
  rm "${HOMEDIR}/maps.txt"

  if [ -n "${map_list}" ]; then
    echo "*** INFO: Added maps including ${map_list} ***"
    sed -i "s/Map=.*/Map=${map_list}Muldraugh, KY/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}.ini"

    # Checks which added maps have spawnpoints.lua files and adds them to the spawnregions file if they aren't already added
    IFS=";" read -ra strings <<< "$map_list"
    for string in "${strings[@]}"; do
        if ! grep -q "$string" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_spawnregions.lua"; then
          if [ -e "${HOMEDIR}/pz-dedicated/media/maps/$string/spawnpoints.lua" ]; then
            result="{ name = \"$string\", file = \"media/maps/$string/spawnpoints.lua\" },"
            sed -i "/function SpawnRegions()/,/return {/ {    /return {/ a\
            \\\t\t$result
            }" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_spawnregions.lua"
          fi
        fi
    done
  fi 
fi

# Fix to a bug in start-server.sh that causes to no preload a library:
# ERROR: ld.so: object 'libjsig.so' from LD_PRELOAD cannot be preloaded (cannot open shared object file): ignored.
export LD_LIBRARY_PATH="${STEAMAPPDIR}/jre64/lib:${LD_LIBRARY_PATH}"

## Fix the permissions in the data and workshop folders
chown -R 1000:1000 /home/steam/pz-dedicated/steamapps/workshop /home/steam/Zomboid
# When binding a host folder with Docker to the container, the resulting folder has these permissions "d---" (i.e. NO `rwx`) 
# which will cause runtime issues after launching the server.
# Fix it the adding back `rwx` permissions for the file owner (steam user)
chmod 755 /home/steam/Zomboid

su - steam -c "export LANG=${LANG} && export LD_LIBRARY_PATH=\"${STEAMAPPDIR}/jre64/lib:${LD_LIBRARY_PATH}\" && cd ${STEAMAPPDIR} && pwd && ./start-server.sh ${ARGS}"
