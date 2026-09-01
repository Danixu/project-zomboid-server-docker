#!/bin/bash

########################333333##################
##                                            ##
## This script has not been tested yet.       ##
## Waiting for a new server version to do it. ##
##                                            ##
########################333333##################

DOCKER_IMAGE="danixu86/project-zomboid-dedicated-server"
PZ_URL_WEB="https://projectzomboid.com/blog/"
PZ_URL_FORUM="https://theindiestone.com/forums/forum/35-pz-updates/"
BUILD_UNSTABLE_VERSIONS=true
# Build even when the detected server version is not newer than the published image. The
# image is only rebuilt when Project Zomboid itself gets a new version, so a change to the
# Dockerfile or to the scripts never reaches Docker Hub on its own. The result is published
# as a new revision of the current version, never on top of the existing tag.
FORCE_BUILD="${FORCE_BUILD:-false}"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "${SCRIPT_DIR}/../"

###########################################
##
## Function to compare two version numbers
##
## Return:
##   1: First version is higher
##  -1: Second version is higher
##   0: Both versions are equal
##
function versionCompare(){
  A_LENGTH=`echo -n $1|sed 's/[^\.]*//g'|wc -m`
  B_LENGTH=`echo -n $2|sed 's/[^\.]*//g'|wc -m`

  REVERSE=0
  A=""
  B=""

  if [ ${B_LENGTH} -gt ${A_LENGTH} ]; then
    A=$2
    B=$1
    REVERSE=1
  else
    A=$1
    B=$2
  fi

  CURRENT=1
  A_NUM=`echo -n $A|cut -d "." -f${CURRENT}`

  while [ "${A_NUM}" != "" ]; do
    B_NUM=`echo -n $B|cut -d "." -f${CURRENT}`

    if [ "$B_NUM" == "" ] || [ $A_NUM -gt $B_NUM ]; then
      if [ $REVERSE == 1 ]; then echo -1; else echo 1; fi
      return 0;
    elif [ $B_NUM -gt $A_NUM ]; then
      if [ $REVERSE == 1 ]; then echo 1; else echo -1; fi
      return 0;
    fi

    CURRENT=$((${CURRENT} + 1))
    A_NUM=`echo -n $A|cut -d "." -f${CURRENT}`
  done
  echo 0
}

##########################################
##                                      ##
## Checking the latest built version    ##
##                                      ##
##########################################
LATEST_IMAGES=`curl -L -s "https://registry.hub.docker.com/v2/repositories/${DOCKER_IMAGE}/tags?page_size=1024" | jq  '.results[]["name"]' | grep -iv "latest" | sort`
# Get the latest stable version
LATEST_IMAGE_STABLE_VERSION=`echo "${LATEST_IMAGES}" | grep -i "release" | tail -n1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+|[0-9]+\.[0-9]+" | sed 's/"//g'`
# Get the latest unstable version.
LATEST_IMAGE_UNSTABLE_VERSION=`echo "${LATEST_IMAGES}" | grep -i "unstable" | tail -n1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+|[0-9]+\.[0-9]+" | sed 's/"//g'`
echo "Latest docker images version:"
echo -e "\tRELEASE: ${LATEST_IMAGE_STABLE_VERSION}"
echo -e "\tUNSTABLE: ${LATEST_IMAGE_UNSTABLE_VERSION}"

##########################################
##                                      ##
## Checking the latest version in Forum ##
##                                      ##
##########################################
# Texts to search on the forum
STABLE_TITLES="STABLE"
UNSTABLE_TITLES="BETA|HOTFIX|UNSTABLE"
# Forum data
FORUM_DATA=`curl -s "${PZ_URL_FORUM}"`
# Get the latest stable versions to filter it later
LATEST_FORUM_STABLE_VERSIONS=$(echo "${FORUM_DATA}" | \
grep -oPi "[0-9]{2,3}\.[0-9]{1,2}(\.[0-9]{1,2})? ($STABLE_TITLES)" | \
grep -oE "[0-9]+\.[0-9]+\.[0-9]+|[0-9]+\.[0-9]+" | sort | uniq)
# Get the latest unstable versions to filter it later
LATEST_FORUM_UNSTABLE_VERSIONS=$(echo "${FORUM_DATA}" | \
grep -oPi "[0-9]{2,3}\.[0-9]{1,2}(\.[0-9]{1,2})? ($UNSTABLE_TITLES)" | \
grep -oE "[0-9]+\.[0-9]+\.[0-9]+|[0-9]+\.[0-9]+" | sort | uniq)

# Sometimes a pinned post hiddens the latest version, so all versions will be checked
LATEST_FORUM_STABLE_VERSION=0.0.0
for version in $LATEST_FORUM_STABLE_VERSIONS; do
  COMPARE_VERSION=$(versionCompare ${LATEST_FORUM_STABLE_VERSION} ${version})
  if [ $COMPARE_VERSION == -1 ]; then
    LATEST_FORUM_STABLE_VERSION=$version
  fi
done
LATEST_FORUM_UNSTABLE_VERSION=0.0.0
for version in $LATEST_FORUM_UNSTABLE_VERSIONS; do
  COMPARE_VERSION=$(versionCompare ${LATEST_FORUM_UNSTABLE_VERSION} ${version})
  if [ $COMPARE_VERSION == -1 ]; then
    LATEST_FORUM_UNSTABLE_VERSION=$version
  fi
done

echo -e "\n\nLatest forum versions:"
echo -e "\tRELEASE: ${LATEST_FORUM_STABLE_VERSION}"
echo -e "\tUNSTABLE: ${LATEST_FORUM_UNSTABLE_VERSION}"

################################################
##                                            ##
## Checking the latest version in the webpage ##
##                                            ##
################################################
# Texts to search on the webpage
STABLE_TEXT="Stable Build"
UNSTABLE_TEXT="IWBUMS Beta"

# Extract the versions from the website (sometimes it is outdated, that is why I check first the forum)
WEBPAGE_DATA=`curl "${PZ_URL_WEB}" 2>/dev/null`
LATEST_WEBPAGE_STABLE_VERSION=`echo "${WEBPAGE_DATA}" | grep -i "${STABLE_TEXT}" | head -n1 | cut -d ":" -f2 | awk '{print $1}'`
LATEST_WEBPAGE_UNSTABLE_VERSION=`echo "${WEBPAGE_DATA}" | grep -i "${UNSTABLE_TEXT}" | head -n1 | cut -d ":" -f2 | awk '{print $1}'`

echo -e "\n\nLatest website versions:"
echo -e "\tRELEASE: ${LATEST_WEBPAGE_STABLE_VERSION}"
echo -e "\tUNSTABLE: ${LATEST_WEBPAGE_UNSTABLE_VERSION}"


##################################
##                              ##
## Building the required images ##
##                              ##
##################################

LATEST_STABLE_VERSION=""
LATEST_STABLE_VERSION_COMPARE=$(versionCompare ${LATEST_FORUM_STABLE_VERSION} ${LATEST_WEBPAGE_STABLE_VERSION})
if [ $LATEST_STABLE_VERSION_COMPARE == -1 ]; then
  LATEST_STABLE_VERSION=$LATEST_WEBPAGE_STABLE_VERSION
else
  LATEST_STABLE_VERSION=$LATEST_FORUM_STABLE_VERSION
fi

LATEST_UNSTABLE_VERSION=""
LATEST_UNSTABLE_VERSION_COMPARE=$(versionCompare ${LATEST_FORUM_UNSTABLE_VERSION} ${LATEST_WEBPAGE_UNSTABLE_VERSION})
if [ $LATEST_UNSTABLE_VERSION_COMPARE == -1 ]; then
  LATEST_UNSTABLE_VERSION=$LATEST_WEBPAGE_UNSTABLE_VERSION
else
  LATEST_UNSTABLE_VERSION=$LATEST_FORUM_UNSTABLE_VERSION
fi

echo -e "\n\nDetected real latest versions (forum and website):"
echo -e "\tRELEASE: ${LATEST_STABLE_VERSION}"
echo -e "\tUNSTABLE: ${LATEST_UNSTABLE_VERSION}"

if [ ${BUILD_UNSTABLE_VERSIONS} == true ]; then
  echo -e "\n\n****************************************************************************"
  echo "The unstable image build is enabled. Checking latest version..."

  NEW_VERSION=$(versionCompare ${LATEST_UNSTABLE_VERSION} ${LATEST_IMAGE_UNSTABLE_VERSION})

  # Project Zomboid does not always have an open beta. When Build 42 became stable the
  # "unstable" beta was removed from Steam, but the forum and the website keep reporting a
  # version for it (the very same one as the stable build), so the script went on trying
  # to build it and SteamCMD answered "ERROR! Failed to set beta 'unstable'" every time.
  # A beta is only worth building while it is actually ahead of the stable build.
  UNSTABLE_AHEAD=$(versionCompare ${LATEST_UNSTABLE_VERSION} ${LATEST_STABLE_VERSION})

  if [ "${UNSTABLE_AHEAD}" != 1 ]; then
    echo -e "\n\nThe detected unstable version (${LATEST_UNSTABLE_VERSION}) is not ahead of the stable one (${LATEST_STABLE_VERSION}), so there is no open beta right now. Skipping the unstable image.\n\n"
  elif [ "${FORCE_BUILD}" == "true" ] || [ "${LATEST_IMAGE_UNSTABLE_VERSION}" == "" ] || [ $NEW_VERSION == 1 ]; then
    if [ "${FORCE_BUILD}" == "true" ]; then
      echo -e "\n\nFORCE_BUILD is set, rebuilding the unstable image ($LATEST_UNSTABLE_VERSION) as a new revision...\n"
    else
      echo -e "\n\nA new version of the unstable server was detected ($LATEST_UNSTABLE_VERSION). Creating the new image...\n"
    fi

    # An empty version would build the invalid tag "<image>:-unstable", but above all it
    # means the version detection failed and the script should stop instead of publishing
    # something wrong.
    if [ -z "${LATEST_UNSTABLE_VERSION}" ] || [ "${LATEST_UNSTABLE_VERSION}" == "0.0.0" ]; then
      echo -e "\n\n*** ERROR: no unstable version could be detected in the forum or the website, aborting ***\n\n"
      exit 1
    fi

    # Stop at the first failure instead of pushing tags that were never built.
    # Same as the stable image: an already published version is republished as the next
    # revision instead of overwriting the tag someone may have pinned.
    UNSTABLE_TAG="${LATEST_UNSTABLE_VERSION}-unstable"
    if echo "${LATEST_IMAGES}" | grep -q "\"${UNSTABLE_TAG}\""; then
      REVISION=2
      while echo "${LATEST_IMAGES}" | grep -q "\"${LATEST_UNSTABLE_VERSION}-unstable-${REVISION}\""; do
        REVISION=$((REVISION + 1))
      done
      UNSTABLE_TAG="${LATEST_UNSTABLE_VERSION}-unstable-${REVISION}"
      echo "Version ${LATEST_UNSTABLE_VERSION} is already published, publishing it as ${UNSTABLE_TAG} to leave the existing tag untouched"
    fi

    docker build --compress --no-cache --build-arg STEAMAPPBRANCH=unstable -t ${DOCKER_IMAGE}:latest-unstable -t ${DOCKER_IMAGE}:${UNSTABLE_TAG} . || exit 1
    docker push ${DOCKER_IMAGE}:${UNSTABLE_TAG} || exit 1
    docker push ${DOCKER_IMAGE}:latest-unstable || exit 1
  elif [ $NEW_VERSION == 0 ]; then
    echo -e "\n\nThere is no new unstable version of the Zomboid server\n\n"
  elif [ $NEW_VERSION == -1 ]; then
    echo -e "\n\nServer unstable version (${LATEST_UNSTABLE_VERSION}) is lower than latest docker version (${LATEST_IMAGE_UNSTABLE_VERSION})... Please, check this script because maybe is not working correctly\n\n"
  else
    echo -e "\n\nThere was an unknown error checking the unstable version.\n\n"
  fi
  echo "****************************************************************************"
  echo -e "\n\n"
fi

echo -e "\n\n****************************************************************************"
echo "Checking the latest stable version..."
NEW_VERSION=$(versionCompare ${LATEST_STABLE_VERSION} ${LATEST_IMAGE_STABLE_VERSION})

if [ "${FORCE_BUILD}" == "true" ] || [ "${LATEST_IMAGE_STABLE_VERSION}" == "" ] || [ $NEW_VERSION == 1 ]; then
  if [ "${FORCE_BUILD}" == "true" ]; then
    echo -e "\n\nFORCE_BUILD is set, rebuilding the stable image ($LATEST_STABLE_VERSION) as a new revision...\n"
  else
    echo -e "\n\nA new version of the stable server was detected ($LATEST_STABLE_VERSION). Creating the new image...\n"
  fi

  # An empty version would build the invalid tag "<image>:-release", but above all it
  # means the version detection failed and the script should stop instead of publishing
  # something wrong.
  if [ -z "${LATEST_STABLE_VERSION}" ] || [ "${LATEST_STABLE_VERSION}" == "0.0.0" ]; then
    echo -e "\n\n*** ERROR: no stable version could be detected in the forum or the website, aborting ***\n\n"
    exit 1
  fi

  # Stop at the first failure. Only the exit status of the last push used to be reported,
  # so a failed build or a failed intermediate push was masked by the "latest" push that
  # followed it and the job still looked green.
  # Never overwrite a version tag that is already published: whoever pinned
  # 42.20.4-release has to keep getting the very same image. When the version is already
  # out and the image is built again (because the Dockerfile or the scripts changed), it
  # goes out as the next revision of that version instead, and the moving tags follow it.
  STABLE_TAG="${LATEST_STABLE_VERSION}-release"
  if echo "${LATEST_IMAGES}" | grep -q "\"${STABLE_TAG}\""; then
    REVISION=2
    while echo "${LATEST_IMAGES}" | grep -q "\"${LATEST_STABLE_VERSION}-release-${REVISION}\""; do
      REVISION=$((REVISION + 1))
    done
    STABLE_TAG="${LATEST_STABLE_VERSION}-release-${REVISION}"
    echo "Version ${LATEST_STABLE_VERSION} is already published, publishing it as ${STABLE_TAG} to leave the existing tag untouched"
  fi

  docker build --compress --no-cache -t ${DOCKER_IMAGE}:latest -t ${DOCKER_IMAGE}:latest-release -t ${DOCKER_IMAGE}:${STABLE_TAG} . || exit 1
  docker push ${DOCKER_IMAGE}:${STABLE_TAG} || exit 1
  docker push ${DOCKER_IMAGE}:latest-release || exit 1
  docker push ${DOCKER_IMAGE}:latest || exit 1
elif [ $NEW_VERSION == 0 ]; then
  echo -e "\n\nThere is no new stable version of the Zomboid server\n\n"
elif [ $NEW_VERSION == -1 ]; then
  echo -e "\n\nServer stable version (${LATEST_STABLE_VERSION}) is lower than latest docker version (${LATEST_IMAGE_STABLE_VERSION})... Please, check this script because maybe is not working correctly\n\n"
else
  echo -e "\n\nThere was an unknown error checking the stable version.\n\n"
fi
echo "****************************************************************************"
echo -e "\n\n"
