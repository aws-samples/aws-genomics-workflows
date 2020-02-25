#!/bin/bash

set -e

IMAGE_NAME=$1
IMAGE_TAG=$2

# build the base image
docker build --build-arg VERSION=$IMAGE_TAG -t $IMAGE_NAME .

# build the image with an AWS specific entrypoint
docker build --build-arg BASE_IMAGE=$IMAGE_NAME -t $IMAGE_NAME:$IMAGE_TAG -t $IMAGE_NAME:latest -f _common/aws.dockerfile .