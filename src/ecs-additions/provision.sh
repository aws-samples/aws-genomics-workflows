#!/bin/bash

set -e
set -x

export OS=`uname -r`
BASEDIR=`dirname $0`

# Expected environment variables
#   GWFCORE_NAMESPACE
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

ARTIFACT_S3_ROOT_URL=$(\
    aws ssm get-parameter \
        --name /gwfcore/${GWFCORE_NAMESPACE}/installed-artifacts/s3-root-url \
        --query 'Parameter.Value' \
        --output text \
)

ORCHESTRATOR_EXIST=$(\
    aws ssm describe-parameters \
        --filters "Key=Name,Values=/gwfcore/${GWFCORE_NAMESPACE}/orchestrator" | jq '.Parameters | length > 0')

if [[ "$ORCHESTRATOR_EXIST" = true ]]
then
    WORKFLOW_ORCHESTRATOR=$(\
        aws ssm get-parameter \
            --name /gwfcore/${GWFCORE_NAMESPACE}/orchestrator \
            --query 'Parameter.Value' \
            --output text)
fi

# retrieve and install amazon-ebs-autoscale
cd /opt
sh $BASEDIR/get-amazon-ebs-autoscale.sh \
    --install-version dist_release \
    --artifact-root-url $ARTIFACT_S3_ROOT_URL \
    --file-system btrfs

# common provisioning for all workflow orchestrators
cd /opt
sh $BASEDIR/ecs-additions-common.sh

# workflow specific provisioning if needed
if [[ $WORKFLOW_ORCHESTRATOR ]]; then
    if [ -f "$BASEDIR/ecs-additions-$WORKFLOW_ORCHESTRATOR.sh" ]; then
        sh $BASEDIR/ecs-additions-$WORKFLOW_ORCHESTRATOR.sh
    fi
fi
