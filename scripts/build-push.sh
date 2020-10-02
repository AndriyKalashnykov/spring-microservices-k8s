#!/bin/bash

set -x

REPO_USER=${1:-andriykalashnykov}
IS_DEBUG_VERSION=${2:-true}
APP_VER=${3:-1.2}

DEBUG_IMAGE_SUFFIX=""
DEBUG_DOCKERFILE_NAME="Dockerfile"

CURRENT_DIR=`pwd`
SCRIPT_DIR=$(dirname $0)

if [ "$IS_DEBUG_VERSION" == "true" ]; then
    DEBUG_IMAGE_SUFFIX="-debug"
    DEBUG_DOCKERFILE_NAME="Dockerfile.debug"
fi

docker login

cd ../$SCRIPT_DIR/employee-service
docker build -f ${DEBUG_DOCKERFILE_NAME} -t vmware/employee${DEBUG_IMAGE_SUFFIX}:$APP_VER .
docker tag vmware/employee${DEBUG_IMAGE_SUFFIX}:$APP_VER $REPO_USER/employee${DEBUG_IMAGE_SUFFIX}:$APP_VER
docker push $REPO_USER/employee${DEBUG_IMAGE_SUFFIX}:$APP_VER

cd ../$SCRIPT_DIR/department-service
docker build -f ${DEBUG_DOCKERFILE_NAME} -t vmware/department${DEBUG_IMAGE_SUFFIX}:$APP_VER .
docker tag vmware/department${DEBUG_IMAGE_SUFFIX}:$APP_VER $REPO_USER/department${DEBUG_IMAGE_SUFFIX}:$APP_VER
docker push $REPO_USER/department${DEBUG_IMAGE_SUFFIX}:$APP_VER

cd ../$SCRIPT_DIR/organization-service
docker build -f ${DEBUG_DOCKERFILE_NAME} -t vmware/organization${DEBUG_IMAGE_SUFFIX}:$APP_VER .
docker tag vmware/organization${DEBUG_IMAGE_SUFFIX}:$APP_VER $REPO_USER/organization${DEBUG_IMAGE_SUFFIX}:$APP_VER
docker push $REPO_USER/organization${DEBUG_IMAGE_SUFFIX}:$APP_VER

cd ../$SCRIPT_DIR/gateway-service
docker build -f ${DEBUG_DOCKERFILE_NAME} -t vmware/gateway${DEBUG_IMAGE_SUFFIX}:$APP_VER .
docker tag vmware/gateway${DEBUG_IMAGE_SUFFIX}:$APP_VER $REPO_USER/gateway${DEBUG_IMAGE_SUFFIX}:$APP_VER
docker push $REPO_USER/gateway${DEBUG_IMAGE_SUFFIX}:$APP_VER

cd $CURRENT_DIR

docker images