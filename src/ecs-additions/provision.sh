#!/bin/bash

set -e
set -x

OS="$(uname -r)"
BASEDIR="$(dirname "${0}")"

export OS

# Expected environment variables
GWFCORE_NAMESPACE=$1
ARTIFACT_S3_ROOT_URL=$2
#   WORKFLOW_ORCHESTRATOR (OPTIONAL)

printenv

# start ssm-agent
if [[ $OS =~ "amzn1" ]]; then
    start amazon-ssm-agent
elif [[ $OS =~ "amzn2" ]]; then
    echo "Stopping and upgrading amazon ssm agent" 1>&2
    systemctl stop amazon-ssm-agent
    systemctl disable amazon-ssm-agent
    echo "Downloading latest version" 1>&2
    curl \
      --output "amazon-ssm-agent.rpm" \
      "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm"
    echo "Upgrading ssm agent to latest version" 1>&2
    rpm \
      --quiet \
      --install \
      --force \
      --upgrade \
      --replacepkgs \
      "amazon-ssm-agent.rpm"
    echo "Re-enabling amazon ssm agent" 1>&2
    systemctl enable --output=verbose amazon-ssm-agent
    systemctl start --output=verbose amazon-ssm-agent
    echo "Cleaning up" 1>&2
    rm "amazon-ssm-agent.rpm"
else
    echo "unsupported os: ${OS}"
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
        echo "unsupported os: ${OS}"
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
        --name "/gwfcore/${GWFCORE_NAMESPACE}/installed-artifacts/s3-root-url" \
        --query 'Parameter.Value' \
        --output text \
)

ORCHESTRATOR_EXIST=$(\
    aws ssm describe-parameters \
        --filters "Key=Name,Values=/gwfcore/${GWFCORE_NAMESPACE}/orchestrator" | \
    jq '.Parameters | length > 0' \
)

if [[ "$ORCHESTRATOR_EXIST" == "true" ]]; then
    WORKFLOW_ORCHESTRATOR=$(\
        aws ssm get-parameter \
            --name "/gwfcore/${GWFCORE_NAMESPACE}/orchestrator" \
            --query 'Parameter.Value' \
            --output text \
    )
fi

# retrieve and install amazon-ebs-autoscale
cd /opt
bash "${BASEDIR}/get-amazon-ebs-autoscale.sh" \
    --install-version dist_release \
    --artifact-root-url "${ARTIFACT_S3_ROOT_URL}" \
    --file-system btrfs

# common provisioning for all workflow orchestrators
cd /opt
bash "${BASEDIR}/ecs-additions-common.sh"

# workflow specific provisioning if needed
if [[ -n "$WORKFLOW_ORCHESTRATOR" ]]; then
    if [[ -f "$BASEDIR/ecs-additions-$WORKFLOW_ORCHESTRATOR.sh" ]]; then
        bash "$BASEDIR/ecs-additions-$WORKFLOW_ORCHESTRATOR.sh"
    fi
fi
