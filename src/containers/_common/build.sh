#!/bin/bash
set -e

IMAGE_NAME=$1
IMAGE_TAG=$2

echo "Docker Login to ECR"
eval $(aws ecr get-login --no-include-email --region ${AWS_REGION})

# retrieve image layer cache from previously built build stage
docker pull ${REGISTRY}/${IMAGE_NAME}:build-${IMAGE_TAG} || true

# (re)build just the build stage of the image
docker build \
    --target build \
    --cache-from ${REGISTRY}/${IMAGE_NAME}:build-${IMAGE_TAG} \
    --build-arg VERSION=$IMAGE_TAG \
    -t ${REGISTRY}/${IMAGE_NAME}:build-${IMAGE_TAG} .

# build the base image
docker build \
    --cache-from ${REGISTRY}/${IMAGE_NAME}:build-${IMAGE_TAG} \
    --build-arg VERSION=$IMAGE_TAG \
    -t $IMAGE_NAME .

# build the image with an AWS specific entrypoint
docker build \
    --build-arg BASE_IMAGE=$IMAGE_NAME \
    -t $IMAGE_NAME:$IMAGE_TAG \
    -t $IMAGE_NAME:latest \
    -f _common/aws.dockerfile .