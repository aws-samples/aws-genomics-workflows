#!/bin/bash

set -e
set -x

# Expected environment variables
#   EBS_AUTOSCALE_VERSION
#   EBS_AUTOSCALE_FILESYSTEM
#   ARTIFACT_ROOT_URL
#   ARTIFACT_HTTP_ROOT_URL
#   ARTIFACT_S3_ROOT_URL
#   WORKFLOW_ORCHESTRATOR

function ecs() {
    case $1 in
        disable)
            systemctl stop ecs
            systemctl stop docker
            ;;
        enable)
            systemctl start docker
            systemctl enable --now --no-block ecs  # see: https://github.com/aws/amazon-ecs-agent/issues/1707
            ;;
    esac
}

# make sure that docker and ecs are running on script exit to avoid
# zombie instances
trap "ecs enable" INT ERR EXIT

ecs disable

aws s3 cp --no-progress $ARTIFACT_S3_ROOT_URL/get-amazon-ebs-autoscale.sh /opt
aws s3 cp --no-progress $ARTIFACT_S3_ROOT_URL/aws-ecs-additions.tgz /opt

cd /opt
tar -xzf aws-ecs-additions.tgz
sh /opt/get-amazon-ebs-autoscale.sh $EBS_AUTOSCALE_VERSION $ARTIFACT_S3_ROOT_URL
sh /opt/ecs-additions/ecs-additions-common.sh
sh /opt/ecs-additions/ecs-additions-$WORKFLOW_ORCHESTRATOR.sh
