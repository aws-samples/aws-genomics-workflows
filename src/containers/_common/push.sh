#!/bin/bash
set -e

IMAGE_NAME=$1
IMAGE_TAG=$2

echo "Docker Login to ECR"
eval $(aws ecr get-login --no-include-email --region ${AWS_REGION})

# # this script expects the image repository to be created by CFN stack prior to build
# 
# # alternatively, you can create the image repository directly via the aws cli if it does not exist
# aws ecr describe-repositories --repository-names ${IMAGE_NAME} \
# || aws ecr create-repository --repository-name ${IMAGE_NAME}
# 
# # and add an appropriate lifecycle policy
# lifecycle_policy=$(cat <<EOF
# {
#     "rules": [
#         {
#             "rulePriority": 1,
#             "description": "Keep only one untagged image, expire all others",
#             "selection": {
#                 "tagStatus": "untagged",
#                 "countType": "imageCountMoreThan",
#                 "countNumber": 1
#             },
#             "action": {
#                 "type": "expire"
#             }
#         }
#     ]
# }
# EOF
# )
# aws ecr put-lifecycle-policy --repository-name ${IMAGE_NAME} --lifecycle-policy-text "$lifecycle_policy"


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