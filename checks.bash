#!/usr/bin/env bash

# Script configuration
# You can set the following environment variables
BONITA_BUILD_NO_CLEAN=${BONITA_BUILD_NO_CLEAN:-false}
BONITA_BUILD_QUIET=${BONITA_BUILD_QUIET:-false}
BONITA_BUILD_STUDIO_ONLY=${BONITA_BUILD_STUDIO_ONLY:-false}
BONITA_BUILD_STUDIO_SKIP=${BONITA_BUILD_STUDIO_SKIP:-false}

# Bonita version
BONITA_BPM_VERSION=7.9.4


########################################################################################################################
# PARAMETERS PARSING AND VALIDATIONS
########################################################################################################################

OS_IS_LINUX=false
OS_IS_MAC=false
OS_IS_WINDOWS=false

detectOS() {
    case "`uname`" in
      CYGWIN*)  OS_IS_WINDOWS=true;;
      MINGW*)   OS_IS_WINDOWS=true;;
      Darwin*)  OS_IS_MAC=true;;
      *)        OS_IS_LINUX=true;;
    esac
}

logBuildInfo() {
    echo "OS information"
    if [[ "${OS_IS_LINUX}" == "true" ]]; then
        echo "  > Run on Linux"
        echo "$(cat /etc/lsb-release)" | xargs -L 1 -I % echo "      %"
    elif [[ "${OS_IS_MAC}" == "true" ]]; then
        echo "  > Run on MacOS"
        echo "$(sw_vers)" | xargs -L 1 -I % echo "      %"
    else
        echo "  > Run on Windows"
        echo "$(wmic os get Caption,OSArchitecture,Version //value)" | xargs -L 1 -I % echo "      %"
    fi
    echo "  > Generic information: $(uname -a)"

    echo "Build environment"
    echo "  > Use $(git --version)"
    echo "  > Commit: $(git rev-parse FETCH_HEAD)"

    echo "Build settings"
    echo "  > BONITA_BPM_VERSION: ${BONITA_BPM_VERSION}"
    echo "  > BONITA_BUILD_NO_CLEAN: ${BONITA_BUILD_NO_CLEAN}"
    echo "  > BONITA_BUILD_QUIET: ${BONITA_BUILD_QUIET}"
    echo "  > BONITA_BUILD_STUDIO_ONLY: ${BONITA_BUILD_STUDIO_ONLY}"
    echo "  > BONITA_BUILD_STUDIO_SKIP: ${BONITA_BUILD_STUDIO_SKIP}"
}

checkPrerequisites() {
    echo "Prerequisites"
    if [[ "${OS_IS_LINUX}" == "true" ]]; then
        if [[ "${BONITA_BUILD_STUDIO_SKIP}" == "false" ]]; then
            # Test that x server is running. Required to generate Bonita Studio models
            # Can be ignored if Studio is build without the "generate" Maven profile

            if ! xset q &>/dev/null; then
                echo "No X server at \$DISPLAY [$DISPLAY]" >&2
                exit 1
            fi
            echo "  > X server running correctly"
        fi
    fi

    # Test that Maven exists
    # FIXME: remove once all projects includes Maven wrapper
    if hash mvn 2>/dev/null; then
        MAVEN_VERSION="$(mvn --version 2>&1 | awk -F " " 'NR==1 {print $3}')"
        echo "  > Use Maven version: $MAVEN_VERSION"
    else
        echo "Maven not found. Exiting."
        exit 1
    fi

    # Test if Curl exists
    if hash curl 2>/dev/null; then
        CURL_VERSION="$(curl --version 2>&1  | awk -F " " 'NR==1 {print $2}')"
        echo "  > Use curl version: $CURL_VERSION"
    else
        echo "curl not found. Exiting."
        exit 1
    fi

    checkJavaVersion
}

checkJavaVersion() {
    local JAVA_CMD=
    echo "  > Java prerequisites"
    echo "      Check if Java version is compatible with Bonita"

    if [[ "x$JAVA" = "x" ]]; then
        if [[ "x$JAVA_HOME" != "x" ]]; then
            echo "      JAVA_HOME is set"
            JAVA_CMD="$JAVA_HOME/bin/java"
        else
            echo "      JAVA_HOME is not set. Use java in path"
            JAVA_CMD="java"
        fi
    else
        JAVA_CMD=${JAVA}
    fi
    echo "      Java command path is $JAVA_CMD"

    java_full_version_details=$("$JAVA_CMD" -version 2>&1)
    echo "      JVM details"
    echo "${java_full_version_details}" | xargs -L 1 -I % echo "        %"

    java_full_version=$("$JAVA_CMD" -version 2>&1 | grep -i version | sed 's/.*version "\(.*\)".*$/\1/g')
    echo "      Java full version: $java_full_version"
    if [[ "x$java_full_version" = "x" ]]; then
      echo "No Java command could be found. Please set JAVA_HOME variable to a JDK and/or add the java executable to your PATH"
      exit 1
    fi

    java_version_1st_digit=$(echo "$java_full_version" | sed 's/\(.*\)\..*\..*$/\1/g')
    java_version_expected=8
    # pre Java 9 versions, get minor version
    if [[ "$java_version_1st_digit" -eq "1" ]]; then
      java_version=$(echo "$java_full_version" | sed 's/.*\.\(.*\)\..*$/\1/g')
    else
      java_version=${java_version_1st_digit}
    fi
    echo "      Java version: $java_version"

    if [[ "$java_version" -ne "$java_version_expected" ]]; then
      echo "Invalid Java version $java_version not $java_version_expected. Please set JAVA_HOME environment variable to a valid JDK version, and/or add the java executable to your PATH"
      exit 1
    fi
    echo "      Java version is compatible with Bonita"
}


########################################################################################################################
# MAIN
########################################################################################################################
detectOS
logBuildInfo
checkPrerequisites
