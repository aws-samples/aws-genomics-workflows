#!/bin/bash

set -e
set -x

export OS=`uname -r`

# Expected environment variables
#   EBS_AUTOSCALE_VERSION
#   EBS_AUTOSCALE_FILESYSTEM
#   ARTIFACT_ROOT_URL
#   ARTIFACT_HTTP_ROOT_URL
#   ARTIFACT_S3_ROOT_URL
#   WORKFLOW_ORCHESTRATOR (OPTIONAL)

printenv

# start ssm-agent
if [[ $OS =~ "amzn1" ]]; then
    start amazon-ssm-agent
elif [[ $OS =~ "amzn2" ]]; then
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
else
    echo "unsupported os: $os"
    exit 100
fi

function ecs() {
    
    if [[ $OS =~ "amzn1" ]]; then
        # Amazon Linux 1 uses upstart for init
        case $1 in
            disable)
                stop ecs
                service docker stop
                ;;
            enable)
                service docker start
                start ecs
                ;;
        esac
    elif [[ $OS =~ "amzn2" ]]; then
        # Amazon Linux 2 uses systemd for init
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
    else
        echo "unsupported os: $os"
        exit 100
    fi
}

# make sure that docker and ecs are running on script exit to avoid
# zombie instances
trap "ecs enable" INT ERR EXIT

set +e
ecs disable
set -e

aws s3 cp --no-progress $ARTIFACT_S3_ROOT_URL/get-amazon-ebs-autoscale.sh /opt
aws s3 cp --no-progress $ARTIFACT_S3_ROOT_URL/aws-ecs-additions.tgz /opt

cd /opt
tar -xzf aws-ecs-additions.tgz
sh /opt/get-amazon-ebs-autoscale.sh $EBS_AUTOSCALE_VERSION $ARTIFACT_S3_ROOT_URL
sh /opt/ecs-additions/ecs-additions-common.sh
sh /opt/ecs-additions/ecs-additions-$WORKFLOW_ORCHESTRATOR.sh
