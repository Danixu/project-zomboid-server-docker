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

  if [ "${LATEST_IMAGE_UNSTABLE_VERSION}" == "" ] || [ $NEW_VERSION == 1 ]; then
    echo -e "\n\nA new version of the unstable server was detected ($LATEST_UNSTABLE_VERSION). Creating the new image...\n"

    docker build --compress --no-cache --build-arg STEAMAPPBRANCH=unstable -t ${DOCKER_IMAGE}:latest-unstable -t ${DOCKER_IMAGE}:${LATEST_UNSTABLE_VERSION}-unstable .
    docker push ${DOCKER_IMAGE}:${LATEST_UNSTABLE_VERSION}-unstable
    docker push ${DOCKER_IMAGE}:latest-unstable
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

if [ "${LATEST_IMAGE_STABLE_VERSION}" == "" ] || [ $NEW_VERSION == 1 ]; then
  echo -e "\n\nA new version of the stable server was detected ($LATEST_STABLE_VERSION). Creating the new image...\n"

  docker build --compress --no-cache -t ${DOCKER_IMAGE}:latest -t ${DOCKER_IMAGE}:latest-release -t ${DOCKER_IMAGE}:${LATEST_STABLE_VERSION}-release .
  docker push ${DOCKER_IMAGE}:${LATEST_STABLE_VERSION}-release
  docker push ${DOCKER_IMAGE}:latest-release
  docker push ${DOCKER_IMAGE}:latest
elif [ $NEW_VERSION == 0 ]; then
  echo -e "\n\nThere is no new stable version of the Zomboid server\n\n"
elif [ $NEW_VERSION == -1 ]; then
  echo -e "\n\nServer stable version (${LATEST_STABLE_VERSION}) is lower than latest docker version (${LATEST_IMAGE_STABLE_VERSION})... Please, check this script because maybe is not working correctly\n\n"
else
  echo -e "\n\nThere was an unknown error checking the stable version.\n\n"
fi
echo "****************************************************************************"
echo -e "\n\n"
