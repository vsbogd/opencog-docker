#!/bin/bash
#
# Notes:
# 1. Build's all the images for development. You can also pull the images from
#    docker registry, but they are a bit bulky.
# 2. If your user is not a member of the docker group you can add it by running
#    sudo adduser $USER docker . On restart you would be able to run docker and
#    this script without root privilege.
# 3. This works for docker version >= 1.5.0
# 4. If run without -u option it will not rebuild all the images unless the base
#    ubuntu image is updated.

# Exit on error
set -e

# Environment Variables
## Use's cache by default unless the -u options is passed
CACHE_OPTION=""

## This file/symlinks name
SELF_NAME=$(basename $0)

# Functions
usage() {
printf "Usage: ./%s [OPTIONS]

  OPTIONS:
    -a Pull all images needed for development from hub.docker.com/u/singularitynet/
    -b Build singularitynet/opencog-deps image. It is the base image for
       tools, cogutil, cogserver, and the buildbot images.
    -c Builds singularitynet/cogutil image. It will build singularitynet/opencog-deps
       if it hasn't been built, as it forms its base image.
    -e Builds singularitynet/minecraft image. It will build all needed images if they
       haven't already been built.
    -j Builds singularitynet/jupyter image. It will add jupyter notebook to
    singularitynet/opencog-dev:cli
    -m Builds singularitynet/moses image.
    -p Builds singularitynet/postgres image.
    -r Builds singularitynet/relex image.
    -t Builds singularitynet/opencog-dev:cli image. It will build
    singularitynet/opencog-deps
       and singularitynet/cogutil if they haven't been built, as they form its base
       images.
    -u This option signals all image builds to not use cache.
    -h This help message. \n" "$SELF_NAME"
}

# -----------------------------------------------------------------------------
## Build singularitynet/opencog-deps image.
build_opencog_deps() {
    echo "---- Starting build of singularitynet/opencog-deps ----"
    OCPKG_OPTION=""
    if [ ! -z "$OCPKG_URL" ]; then
        OCPKG_OPTION="--build-arg OCPKG_URL=$OCPKG_URL"
    fi
    docker build $CACHE_OPTION $OCPKG_OPTION -t singularitynet/opencog-deps base
    echo "---- Finished build of singularitynet/opencog-deps ----"
}

## If the singularitynet/opencog-deps image hasn't been built yet then build it.
check_opencog_deps() {
    if [ -z "$(docker images singularitynet/opencog-deps | grep -i opencog-deps)" ]
    then build_opencog_deps
    fi
}

# -----------------------------------------------------------------------------
## Build singularitynet/cogutil image.
build_cogutil() {
    check_opencog_deps
    echo "---- Starting build of singularitynet/cogutil ----"
    docker build $CACHE_OPTION -t singularitynet/cogutil cogutil
    echo "---- Finished build of singularitynet/cogutil ----"

}

## If the singularitynet/cogutil image hasn't been built yet then build it.
check_cogutil() {
    if [ -z "$(docker images singularitynet/cogutil | grep -i cogutil)" ]
    then build_cogutil
    fi
}

# -----------------------------------------------------------------------------
## Build singularitynet/opencog-dev:cli image.
build_dev_cli() {
    check_cogutil
    echo "---- Starting build of singularitynet/opencog-dev:cli ----"
    docker build $CACHE_OPTION -t singularitynet/opencog-dev:cli tools/cli
    echo "---- Finished build of singularitynet/opencog-dev:cli ----"
}

## If the singularitynet/opencog-dev:cli image hasn't been built yet then build it.
check_dev_cli() {
    if [ -z "$(docker images singularitynet/opencog-dev:cli | grep -i opencog-dev)" ]
    then build_dev_cli
    fi
}

# -----------------------------------------------------------------------------
## Pull all images needed for development from hub.docker.com/u/opencog/
pull_dev_images() {
  echo "---- Starting pull of opencog development images ----"
  docker pull singularitynet/opencog-deps
  docker pull singularitynet/cogutil
  docker pull singularitynet/opencog-dev:cli
  docker pull singularitynet/postgres
  docker pull singularitynet/relex
  echo "---- Finished pull of opencog development images ----"
}

# -----------------------------------------------------------------------------
# Main Execution
if [ $# -eq 0 ] ; then NO_ARGS=true ; fi

while getopts "abcehjmprtu" flag ; do
    case $flag in
        a) PULL_DEV_IMAGES=true ;;
        b) BUILD_OPENCOG_BASE_IMAGE=true ;;
        t) BUILD_TOOL_IMAGE=true ;;
        e) BUILD_EMBODIMENT_IMAGE=true ;;
        c) BUILD_COGUTIL_IMAGE=true ;;
        m) BUILD__MOSES_IMAGE=true ;;
        p) BUILD__POSTGRES_IMAGE=true ;;
        r) BUILD_RELEX_IMAGE=true ;;
        j) BUILD_JUPYTER_IMAGE=true ;;
        u) CACHE_OPTION=--no-cache ;;
        h) usage ;;
        \?) usage; exit 1 ;;
        *)  UNKNOWN_FLAGS=true ;;
    esac
done

# NOTE: To avoid repetion of builds don't reorder the sequence here.

if [ $PULL_DEV_IMAGES ] ; then
    pull_dev_images
    exit 0
fi

if [ $BUILD_OPENCOG_BASE_IMAGE ] ; then
    build_opencog_deps
fi

if [ $BUILD_COGUTIL_IMAGE ] ; then
    build_cogutil
fi

if [ $BUILD_TOOL_IMAGE ] ; then
    build_dev_cli
fi

if [ $BUILD_EMBODIMENT_IMAGE ] ; then
    check_dev_cli
    echo "---- Starting build of singularitynet/minecraft ----"
    docker build $CACHE_OPTION -t singularitynet/minecraft:0.1.0 minecraft
    echo "---- Finished build of singularitynet/minecraft ----"
fi

if [ $BUILD__MOSES_IMAGE ] ; then
    check_cogutil
    echo "---- Starting build of singularitynet/moses ----"
    docker build $CACHE_OPTION -t singularitynet/moses moses
    echo "---- Finished build of singularitynet/moses ----"
fi

if [ $BUILD__POSTGRES_IMAGE ] ; then
    echo "---- Starting build of singularitynet/postgres ----"
    docker build $CACHE_OPTION -t singularitynet/postgres postgres
    echo "---- Finished build of singularitynet/postgres ----"
fi

if [ $BUILD_RELEX_IMAGE ] ; then
    echo "---- Starting build of singularitynet/relex ----"
    docker build $CACHE_OPTION -t singularitynet/relex relex
    echo "---- Finished build of singularitynet/relex ----"
fi

if [ $BUILD_JUPYTER_IMAGE ]; then
    check_dev_cli
    echo "---- Starting build of singularitynet/jupyter ----"
    docker build $CACHE_OPTION -t singularitynet/jupyter tools/jupyter_notebook
    echo "---- Finished build of singularitynet/jupyter ----" 
fi

if [ $UNKNOWN_FLAGS ] ; then usage; exit 1 ; fi
if [ $NO_ARGS ] ; then usage ; fi
