#!/usr/bin/env bash

##########################################################################
# Custom Cake bootstrapper script for Linux and OS X.
#
# Script will download .NET Core SDK if missing, restore packages
# for build tools (including Cake) and execute Cake build script.
#
##########################################################################

# define default arguments
TARGET="Default"
CONFIGURATION="Release"
VERBOSITY="verbose"
SCRIPT_ARGUMENTS=()

# parse arguments
for i in "$@"; do
    case $1 in
        -t|--target) TARGET="$2"; shift ;;
        -c|--configuration) CONFIGURATION="$2"; shift ;;
        -v|--verbosity) VERBOSITY="$2"; shift ;;
        --) shift; SCRIPT_ARGUMENTS+=("$@"); break ;;
        *) SCRIPT_ARGUMENTS+=("$1") ;;
    esac
    shift
done

SOLUTION_ROOT=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

###########################################################################
# Prepare .NET Core SDK
###########################################################################

DOTNET_VERSION="1.0.0-preview2-003121"
DOTNET_INSTALLER_URI="https://raw.githubusercontent.com/dotnet/cli/rel/1.0.0-preview2/scripts/obtain/dotnet-install.sh"

DOTNET_PATH=$SOLUTION_ROOT/.dotnet
DOTNET_EXE=$DOTNET_PATH/dotnet
DOTNET_VERSION_FOUND=""

if [ -f "$DOTNET_EXE" ]; then

    DOTNET_VERSION_FOUND=$("$DOTNET_EXE" --version)

    echo "Found .NET Core SDK version $DOTNET_VERSION_FOUND"
fi

if [[
    # .NET Core SDK is not present
    -z "$DOTNET_VERSION_FOUND" ||
    # .NET Core SDK presents but is not of the version we want to go with
    $DOTNET_VERSION != $DOTNET_VERSION_FOUND
]]; then

    echo "Installing .NET Core SDK version $DOTNET_VERSION"

    if [ -d "$DOTNET_PATH" ]; then
        rm -rf "$DOTNET_PATH"
    fi

    if [ ! -d "$DOTNET_PATH" ]; then
        mkdir "$DOTNET_PATH"
    fi

    # download installer script
    curl -Lsfo "$DOTNET_PATH/dotnet-install.sh" "$DOTNET_INSTALLER_URI"

    # .NET Core SDK is installed into local "DOTNET_PATH" folder
    bash "$DOTNET_PATH/dotnet-install.sh" --version "$DOTNET_VERSION" --install-dir "$DOTNET_PATH" --no-path
fi

# make sure that .NET Core SDK has been installed
if [ ! -f "$DOTNET_EXE" ]; then
    echo "Could not find .NET Core SDK at '$DOTNET_EXE'"
    exit 1
fi

export PATH="$DOTNET_PATH":$PATH
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1

###########################################################################
# Prepare Cake and helper tools
###########################################################################

BUILD_PATH=$SOLUTION_ROOT/build
TOOLS_PATH=$SOLUTION_ROOT/tools

TOOLS_PROJECT_JSON=$TOOLS_PATH/project.json
TOOLS_PROJECT_JSON_SRC=$BUILD_PATH/project_build_tools.json

CAKE_FEED="https://api.nuget.org/v3/index.json"

echo "Preparing Cake and build tools"

if [ ! -d "$TOOLS_PATH" ]; then
    echo "Creating tools directory"
    mkdir "$TOOLS_PATH"
fi

echo "Copying project.json from $TOOLS_PROJECT_JSON_SRC"
cp "$TOOLS_PROJECT_JSON_SRC" "$TOOLS_PROJECT_JSON"

dotnet restore "$TOOLS_PATH" --packages "$TOOLS_PATH" --verbosity Warning -f "$CAKE_FEED"
if [ $? -ne 0 ]; then
    echo "Error occured while installing Cake and build tools"
    exit 1
fi

CAKE_EXE=$( ls $TOOLS_PATH/Cake.CoreCLR/*/Cake.dll | sort | tail -n 1 )

# make sure that Cake has been installed
if [ ! -f "$CAKE_EXE" ]; then
    echo "Could not find Cake.exe at '$CAKE_EXE'."
    exit 1
fi

###########################################################################
# Run build script
###########################################################################

exec dotnet "$CAKE_EXE" build.cake -verbosity=$VERBOSITY -configuration=$CONFIGURATION -target=$TARGET "${SCRIPT_ARGUMENTS[@]}"