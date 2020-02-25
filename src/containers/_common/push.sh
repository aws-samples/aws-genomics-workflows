#!/bin/bash
set -e

IMAGE_NAME=$1
IMAGE_TAG=$2

echo "Docker Login to ECR"
eval $(aws ecr get-login --no-include-email --region ${AWS_REGION})

# this script expects the image repository to be created by CFN stack prior to build
# 
# alternatively, you can create the image repository directly via the aws cli if it does not exist
# aws ecr describe-repositories --repository-names ${IMAGE_NAME} \
# || aws ecr create-repository --repository-name ${IMAGE_NAME}

REPOSITORY=$(\
    aws ecr describe-repositories \
        --repository-names ${IMAGE_NAME} \
        --output text \
        --query "repositories[0].repositoryUri")

echo "Image repository: $REPOSITORY"

echo "Tagging container image for ECR"
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REPOSITORY}:${IMAGE_TAG}
docker tag ${IMAGE_NAME}:latest ${REPOSITORY}:latest

echo "Pushing container images to ECR"
docker push ${REPOSITORY}