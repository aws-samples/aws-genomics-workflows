#!/bin/bash
# $1    Nextflow project. Can be an S3 URI, or git repo name.
# $2..  Additional parameters passed on to the nextflow cli

# using nextflow needs the following locations/directories provided as
# environment variables to the container
#  * NF_LOGSDIR: where caching and logging data are stored
#  * NF_WORKDIR: where intermmediate results are stored

set -e  # fail on any error

echo "=== ENVIRONMENT ==="
echo `env`

echo "=== RUN COMMAND ==="
echo "$@"

NEXTFLOW_PROJECT=$1
shift
NEXTFLOW_PARAMS="$@"

# Create the default config using environment variables
# passed into the container
NF_CONFIG=~/.nextflow/config

cat << EOF > $NF_CONFIG
workDir = "$NF_WORKDIR"
process.executor = "awsbatch"
process.queue = "$NF_JOB_QUEUE"
aws.batch.cliPath = "/home/ec2-user/miniconda/bin/aws"
EOF

echo "=== CONFIGURATION ==="
cat ~/.nextflow/config

# AWS Batch places multiple jobs on an instance
# To avoid file path clobbering use the JobID and JobAttempt
# to create a unique path
GUID="$AWS_BATCH_JOB_ID/$AWS_BATCH_JOB_ATTEMPT"

if [ "$GUID" = "/" ]; then
    GUID=`date | md5sum | cut -d " " -f 1`
fi

mkdir -p /opt/work/$GUID
cd /opt/work/$GUID

# stage in session cache
# .nextflow directory holds all session information for the current and past runs.
# it should be `sync`'d with an s3 uri, so that runs from previous sessions can be 
# resumed
echo "== Restoring Session Cache =="
aws s3 sync --only-show-errors $NF_LOGSDIR/.nextflow .nextflow

function preserve_session() {
    # stage out session cache
    if [ -d .nextflow ]; then
        echo "== Preserving Session Cache =="
        aws s3 sync --only-show-errors .nextflow $NF_LOGSDIR/.nextflow
    fi

    # .nextflow.log file has more detailed logging from the workflow run and is
    # nominally unique per run.
    #
    # when run locally, .nextflow.logs are automatically rotated
    # when syncing to S3 uniquely identify logs by the batch GUID
    if [ -f .nextflow.log ]; then
        echo "== Preserving Session Log =="
        aws s3 cp --only-show-errors .nextflow.log $NF_LOGSDIR/.nextflow.log.${GUID/\//.}
    fi
}

trap preserve_session EXIT

# stage workflow definition
if [[ "$NEXTFLOW_PROJECT" =~ ^s3://.* ]]; then
    echo "== Staging S3 Project =="
    aws s3 sync --only-show-errors --exclude 'runs/*' --exclude '.*' $NEXTFLOW_PROJECT ./project
    NEXTFLOW_PROJECT=./project
fi

echo "== Running Workflow =="
echo "nextflow run $NEXTFLOW_PROJECT $NEXTFLOW_PARAMS"
nextflow run $NEXTFLOW_PROJECT $NEXTFLOW_PARAMS