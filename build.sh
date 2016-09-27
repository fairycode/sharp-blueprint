#!/usr/bin/env bash

##########################################################################
# This is the Cake bootstrapper script for Linux and OS X.
# This file was downloaded from https://github.com/cake-build/resources
# Feel free to change this file to fit your needs.
##########################################################################

# define directories
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TOOLS_DIR=$SCRIPT_DIR/tools

DOTNET_DIR=$SCRIPT_DIR/.dotnet
DOTNET_EXE=$DOTNET_DIR/dotnet

CAKE_VERSION=0.16.0-alpha0082
CAKE_FEED=https://www.myget.org/F/cake/api/v3/index.json
CAKE_EXE=$TOOLS_DIR/Cake.CoreCLR/$CAKE_VERSION/Cake.dll

# define default arguments
SCRIPT="build.cake"
TARGET="Default"
CONFIGURATION="Release"
VERBOSITY="verbose"
DRYRUN=
SHOW_VERSION=false
SCRIPT_ARGUMENTS=()

# parse arguments
for i in "$@"; do
    case $1 in
        -s|--script) SCRIPT="$2"; shift ;;
        -t|--target) TARGET="$2"; shift ;;
        -c|--configuration) CONFIGURATION="$2"; shift ;;
        -v|--verbosity) VERBOSITY="$2"; shift ;;
        -d|--dryrun) DRYRUN="-dryrun" ;;
        --version) SHOW_VERSION=true ;;
        --) shift; SCRIPT_ARGUMENTS+=("$@"); break ;;
        *) SCRIPT_ARGUMENTS+=("$1") ;;
    esac
    shift
done

# TODO: explain why TOOLS_DIR is required
if [ ! -d "$TOOLS_DIR" ]; then
    echo "Could not find '$TOOLS_DIR' folder."
    exit 1
fi

###########################################################################
# Install .NET Core CLI
###########################################################################

if [ ! -f "$DOTNET_EXE" ]; then
    echo "Installing .NET CLI..."

    if [ ! -d "$DOTNET_DIR" ]; then
        mkdir "$DOTNET_DIR"
    fi

    # https://github.com/dotnet/cli/blob/rel/1.0.0/Documentation/cli-installation-scenarios.md
    curl -Lsfo "$DOTNET_DIR/dotnet-install.sh" https://raw.githubusercontent.com/dotnet/cli/rel/1.0.0/scripts/obtain/dotnet-install.sh
    bash "$DOTNET_DIR/dotnet-install.sh" --version latest --install-dir $DOTNET_DIR --no-path

    "$DOTNET_DIR/dotnet" --info
fi

# Make sure that dotnet CLI has been installed.
if [ ! -f "$DOTNET_EXE" ]; then
    echo "Could not find dotnet CLI at '$DOTNET_EXE'."
    exit 1
fi

export PATH="$DOTNET_DIR":$PATH
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1

###########################################################################
# Install Cake
###########################################################################

if [ ! -f "$CAKE_EXE" ]; then
    exec $DOTNET_EXE restore "$TOOLS_DIR" --packages "$TOOLS_DIR" -f "$CAKE_FEED"
    if [ $? -ne 0 ]; then
        echo "An error occured while installing Cake."
        exit 1
    fi
fi

# Make sure that Cake has been installed.
if [ ! -f "$CAKE_EXE" ]; then
    echo "Could not find Cake.exe at '$CAKE_EXE'."
    exit 1
fi


###########################################################################
# Run build script
###########################################################################

if $SHOW_VERSION; then
    exec $DOTNET_EXE "$CAKE_EXE" -version
else
    exec $DOTNET_EXE "$CAKE_EXE" $SCRIPT -verbosity=$VERBOSITY -configuration=$CONFIGURATION -target=$TARGET $DRYRUN "${SCRIPT_ARGUMENTS[@]}"
fi