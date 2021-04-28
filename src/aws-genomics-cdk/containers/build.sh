#!/bin/bash
set -e

DEFAULT_PROJECT_NAME="genomics"
IMAGE_NAME=$1
PROJECT_NAME="${2:-$DEFAULT_PROJECT_NAME}"
DOCKER_FILE_PATH="./${IMAGE_NAME}/Dockerfile"
REGISTRY="$CDK_DEFAULT_ACCOUNT.dkr.ecr.$CDK_DEFAULT_REGION.amazonaws.com"
REPOSITORY_NAME="${PROJECT_NAME}/${IMAGE_NAME}"
IMAGE_TAG=":latest"
IMAGE_WITH_TAG="${IMAGE_NAME}${IMAGE_TAG}"
REGISTRY_PATH="${REGISTRY}/${REPOSITORY_NAME}"
REGISTRY_PATH_WITH_TAG="${REGISTRY}/${PROJECT_NAME}/${IMAGE_WITH_TAG}"


if [ -z "${IMAGE_NAME}" ]
then
    echo "Missing image name parameter."
    exit 1
fi

if [[ ! -f "${DOCKER_FILE_PATH}" ]]
then
    echo "${DOCKER_FILE_PATH} does not exist on the filesystem."
    exit 1
fi

if [ -z "$CDK_DEFAULT_ACCOUNT" ]
then
    echo "Missing CDK_DEFAULT_ACCOUNT environment variable."
    exit 1
fi

if [ -z "$CDK_DEFAULT_REGION" ]
then
    echo "Missing CDK_DEFAULT_REGION environment variable."
    exit 1
fi


echo "Docker Login to ECR"
eval $(aws ecr get-login --no-include-email --region ${CDK_DEFAULT_REGION})


# Check if the repository exists in ECR and if not, create it
REPO=`aws ecr describe-repositories | grep -o ${REGISTRY_PATH}` || true
if [  "${REPO}" != "${REGISTRY_PATH}" ]
then
    aws ecr create-repository --repository-name ${REPOSITORY_NAME}
fi

# build the base image
docker build \
    -t ${IMAGE_NAME} \
    -f ${DOCKER_FILE_PATH} .

# build the image with an AWS specific entrypoint
docker build \
    --build-arg BASE_IMAGE=${IMAGE_NAME} \
    -t ${IMAGE_WITH_TAG} \
    -f ./entry.dockerfile .
    

# tag the image
docker tag ${IMAGE_WITH_TAG} ${REGISTRY_PATH}


# push the image to the registry
docker push ${REGISTRY_PATH_WITH_TAG}