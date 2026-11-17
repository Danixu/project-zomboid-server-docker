#!/bin/bash

########################333333##################
##                                            ##
## This script has not been tested yet.       ##
## Waiting for a new server version to do it. ##
##                                            ##
########################333333##################

DOCKER_IMAGE="danixu86/project-zomboid-dedicated-server"
# The game's Steam app id: its news feed is where the version announcements are read from.
STEAM_GAME_APPID=108600
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
## Checking if the images are outdated  ##
##                                      ##
##########################################
# The images are only rebuilt for a new server version, so a change to what goes into them
# (the Dockerfile or the scripts it copies) was never published on its own and had to be
# pushed out by hand with FORCE_BUILD. Compare the last change to those files with the date
# of the published tag instead, and rebuild whenever the code is newer than the image.
#
# --first-parent dates a merged pull request by when it landed on the branch, not by when
# its commits were written, which can be days earlier than the image it has to beat.
# This needs the full history, hence `fetch-depth: 0` in the workflow: in a shallow clone
# the only commit looks like it touched every file, and every run would rebuild.
IMAGE_SOURCES="Dockerfile scripts/entry.sh scripts/search_folder.sh"
LAST_SOURCE_CHANGE=$(git log -1 --first-parent --format=%ct -- ${IMAGE_SOURCES} 2>/dev/null)

# Prints true when the given tag was published before the last change to the image sources.
# Any missing piece of data answers false: a failed lookup must never turn into a rebuild on
# every single run.
image_is_outdated() {
  local published published_ts
  published=$(curl -L -s "https://registry.hub.docker.com/v2/repositories/${DOCKER_IMAGE}/tags/$1" | jq -r '.last_updated // empty' 2>/dev/null)
  published_ts=$(date -d "${published}" +%s 2>/dev/null)
  if [ -z "${published}" ] || [ -z "${published_ts}" ] || [ -z "${LAST_SOURCE_CHANGE}" ]; then
    echo false
  elif [ "${LAST_SOURCE_CHANGE}" -gt "${published_ts}" ]; then
    echo true
  else
    echo false
  fi
}

STABLE_OUTDATED=$(image_is_outdated latest-release)
UNSTABLE_OUTDATED=$(image_is_outdated latest-unstable)
echo -e "\n\nLast change to the image sources: $(date -u -d "@${LAST_SOURCE_CHANGE:-0}" '+%Y-%m-%d %H:%M UTC')"
echo -e "\tRELEASE image outdated: ${STABLE_OUTDATED}"
echo -e "\tUNSTABLE image outdated: ${UNSTABLE_OUTDATED}"

##############################################
##                                          ##
## Checking the latest version on Steam     ##
##                                          ##
##############################################
# This used to scrape the blog and the forum. Both stopped yielding a version: they
# answer 403 to the runner now, and the markup they were parsed with had changed before
# that. Steam's news feed carries the same announcements through a documented API that
# needs no key and no scraping, so it is read instead.
#
# The titles carry the version in the shape the matching below already expected
# ("42.22.2 STABLE Released", "Build 42.21 Unstable Released"), so a version is still a
# number immediately followed by a keyword, and the highest match wins. Items from the
# other feeds Steam mixes in (press coverage, translations) carry no version and drop out
# on their own.
STEAM_NEWS_URL="https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${STEAM_GAME_APPID}&count=30&maxlength=1"

# Keywords that mark a title as announcing a stable or a beta build. PRE-RELEASE is what
# the beta track has been called since Build 42; BETA, UNSTABLE and IWBUMS are its earlier
# names and stay so older announcements keep matching.
STABLE_TITLES="STABLE"
UNSTABLE_TITLES="BETA|HOTFIX|UNSTABLE|IWBUMS|PRE-RELEASE"

NEWS_TITLES=$(curl -L -s "${STEAM_NEWS_URL}" | jq -r '.appnews.newsitems[]?.title')

LATEST_STEAM_STABLE_VERSIONS=$(echo "${NEWS_TITLES}" | \
grep -oPi "[0-9]{2,3}\.[0-9]{1,2}(\.[0-9]{1,2})? ($STABLE_TITLES)" | \
grep -oE "[0-9]+\.[0-9]+\.[0-9]+|[0-9]+\.[0-9]+" | sort | uniq)
LATEST_STEAM_UNSTABLE_VERSIONS=$(echo "${NEWS_TITLES}" | \
grep -oPi "[0-9]{2,3}\.[0-9]{1,2}(\.[0-9]{1,2})? ($UNSTABLE_TITLES)" | \
grep -oE "[0-9]+\.[0-9]+\.[0-9]+|[0-9]+\.[0-9]+" | sort | uniq)

# The feed is not ordered by version and one title can announce several builds at once
# ("42.20.4 STABLE & 42.19.2 UNSTABLE & 41.78.21 LEGACY Hotfixes"), so every match is
# compared and the highest kept.
LATEST_STABLE_VERSION=0.0.0
for version in $LATEST_STEAM_STABLE_VERSIONS; do
  COMPARE_VERSION=$(versionCompare ${LATEST_STABLE_VERSION} ${version})
  if [ $COMPARE_VERSION == -1 ]; then
    LATEST_STABLE_VERSION=$version
  fi
done
LATEST_UNSTABLE_VERSION=0.0.0
for version in $LATEST_STEAM_UNSTABLE_VERSIONS; do
  COMPARE_VERSION=$(versionCompare ${LATEST_UNSTABLE_VERSION} ${version})
  if [ $COMPARE_VERSION == -1 ]; then
    LATEST_UNSTABLE_VERSION=$version
  fi
done

echo -e "\n\nDetected latest versions (Steam news):"
echo -e "\tRELEASE: ${LATEST_STABLE_VERSION}"
echo -e "\tUNSTABLE: ${LATEST_UNSTABLE_VERSION}"

##################################
##                              ##
## Building the required images ##
##                              ##
##################################

# The stable version comes from a single source now, and that source has broken before
# without anything noticing: the detection falls back to the 0.0.0 it was initialised
# with, every version comparison below then reads "the server is older than what we
# published", and the run ends green having built nothing.
#
# There is no legitimate reason for this value to be absent here, so stop at the point
# where it is produced rather than letting it travel.
if [ -z "${LATEST_STABLE_VERSION}" ] || [ "${LATEST_STABLE_VERSION}" == "0.0.0" ]; then
  echo -e "\n\n*** ERROR: no stable version could be read from the Steam news feed (app ${STEAM_GAME_APPID}) ***"
  echo -e "*** Either the feed is unreachable or the announcement titles no longer carry a version number. Nothing can be published until it is fixed. ***\n\n"
  exit 1
fi

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
  elif [ "${FORCE_BUILD}" == "true" ] || [ "${UNSTABLE_OUTDATED}" == "true" ] || [ "${LATEST_IMAGE_UNSTABLE_VERSION}" == "" ] || [ $NEW_VERSION == 1 ]; then
    if [ "${FORCE_BUILD}" == "true" ]; then
      echo -e "\n\nFORCE_BUILD is set, rebuilding the unstable image ($LATEST_UNSTABLE_VERSION) as a new revision...\n"
    elif [ "${UNSTABLE_OUTDATED}" == "true" ]; then
      echo -e "\n\nThe published unstable image is older than the last change to the Dockerfile or the scripts, rebuilding it ($LATEST_UNSTABLE_VERSION).\n"
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

if [ "${FORCE_BUILD}" == "true" ] || [ "${STABLE_OUTDATED}" == "true" ] || [ "${LATEST_IMAGE_STABLE_VERSION}" == "" ] || [ $NEW_VERSION == 1 ]; then
  if [ "${FORCE_BUILD}" == "true" ]; then
    echo -e "\n\nFORCE_BUILD is set, rebuilding the stable image ($LATEST_STABLE_VERSION) as a new revision...\n"
  elif [ "${STABLE_OUTDATED}" == "true" ]; then
    echo -e "\n\nThe published stable image is older than the last change to the Dockerfile or the scripts, rebuilding it ($LATEST_STABLE_VERSION).\n"
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
  echo -e "\n\n*** ERROR: the detected stable version (${LATEST_STABLE_VERSION}) is older than the published image (${LATEST_IMAGE_STABLE_VERSION}) ***"
  echo -e "*** Versions do not move backwards, so the detection is reading the wrong thing. Fix it before trusting any tag this script writes. ***\n\n"
  exit 1
else
  echo -e "\n\n*** ERROR: the stable version check ended in a state this script does not handle (comparison returned '${NEW_VERSION}') ***\n\n"
  exit 1
fi
echo "****************************************************************************"
echo -e "\n\n"
