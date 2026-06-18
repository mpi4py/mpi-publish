#!/bin/bash
set -euo pipefail

SOURCE=package/source
WORKDIR=package/workdir
DESTDIR=package/install
ARCHLIST=${ARCHLIST:-$(uname -m)}

read -r SOURCE_DATE_EPOCH < "$SOURCE"/source-date-epoch
export SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH

if test "$(uname)" = Linux; then
    containerengine=$(basename "$(command -v podman || command -v docker)")
    export CIBW_CONTAINER_ENGINE=$containerengine
    SOURCE="/project/$SOURCE"
    WORKDIR="/host$PWD/$WORKDIR"
    DESTDIR="/host$PWD/$DESTDIR"
    platform=linux
fi
if test "$(uname)" = Darwin; then
    export MACOSX_DEPLOYMENT_TARGET=11.0
    export CIBW_ENABLE=pypy
    export CIBW_BUILD='pp311-*'
    SOURCE="$PWD/$SOURCE"
    WORKDIR="$PWD/$WORKDIR"
    DESTDIR="$PWD/$DESTDIR"
    platform=macos
fi

export CIBW_ARCHS=$ARCHLIST
export CIBW_ENVIRONMENT="SOURCE='$SOURCE' WORKDIR='$WORKDIR' DESTDIR='$DESTDIR'"
export CIBW_ENVIRONMENT_LINUX=$CIBW_ENVIRONMENT
export CIBW_ENVIRONMENT_MACOS=$CIBW_ENVIRONMENT

uvx \
cibuildwheel \
--platform "$platform" \
--output-dir "${1:-dist}" \
--config-file "cibuildwheel.toml" \
package
