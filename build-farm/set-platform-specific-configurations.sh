#!/bin/bash

################################################################################
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=sbin/common/constants.sh
source "$SCRIPT_DIR/../sbin/common/constants.sh"

if [ "${JAVA_TO_BUILD}" != "${JDK8_VERSION}" ]
then
    export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-warnings-as-errors"
fi

export VARIANT_ARG="--build-variant ${VARIANT}"

# Create placeholders for curl --output
if [ ! -d "$SCRIPT_DIR/platform-specific-configurations" ]
then
    mkdir "$SCRIPT_DIR/platform-specific-configurations"
fi
if [ ! -f "$SCRIPT_DIR/platform-specific-configurations/platformConfigFile.sh" ]
then
    touch "$SCRIPT_DIR/platform-specific-configurations/platformConfigFile.sh"
fi
PLATFORM_CONFIG_FILEPATH="$SCRIPT_DIR/platform-specific-configurations/platformConfigFile.sh"

# Setup for platform config download
rawGithubSource="https://raw.githubusercontent.com"
ret=0
fileContents=""

# Uses curl to download the platform config file
# param 1: LOCATION - Repo path to where the file is located
# param 2: SUFFIX - Operating system to append
function downloadPlatformConfigFile () {
    echo "Attempting to download platform configuration file from ${rawGithubSource}/$1/$2"
    # make-adopt-build-farm.sh has 'set -e'. We need to disable that for the fallback mechanism, as downloading might fail
    set +e
    curl "${rawGithubSource}/$1/$2" > "${PLATFORM_CONFIG_FILEPATH}"
    ret=$?
    # A download will succeed if location is a directory, so we also check the contents are valid
    fileContents=$(cat $PLATFORM_CONFIG_FILEPATH)
    set -e
}

# Attempt to download and source the user's custom platform config
downloadPlatformConfigFile "${PLATFORM_CONFIG_LOCATION}" ""
# Regex to spot github api error messages similar to "404: Not Found"
contentsErrorRegex="#!/bin/bash"

if [ $ret -ne 0 ] || [[ ! $fileContents =~ $contentsErrorRegex ]]
then
    # Check to make sure that a OS file doesn't exist if we can't find a config file from the direct link
    echo "[WARNING] Failed to find a user configuration file, ${rawGithubSource}/${PLATFORM_CONFIG_LOCATION} is likely a directory so we will try and search for a ${OPERATING_SYSTEM}.sh file."
    downloadPlatformConfigFile "${PLATFORM_CONFIG_LOCATION}" "${OPERATING_SYSTEM}.sh"

    if [ $ret -ne 0 ] || [[ ! $fileContents =~ $contentsErrorRegex ]]
    then
        # If there is no user platform config, use adopt's as a default instead
        echo "[WARNING] Failed to download a user platform configuration file. Downloading Adopt's ${OPERATING_SYSTEM}.sh configuration file instead."
        downloadPlatformConfigFile "${ADOPT_PLATFORM_CONFIG_LOCATION}" "${OPERATING_SYSTEM}.sh"

        if [ $ret -ne 0 ] || [[ ! $fileContents =~ $contentsErrorRegex ]]
        then
            echo "[ERROR] Failed to download a platform configuration file from User and Adopt's repositories"
            exit 2
        fi
    fi
fi

echo "[SUCCESS] Config file downloaded successfully to ${PLATFORM_CONFIG_FILEPATH}"
source "${PLATFORM_CONFIG_FILEPATH}"
