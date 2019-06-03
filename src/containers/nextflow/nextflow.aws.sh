#!/bin/bash
# $1    S3 URI to Nextflow project files.  If not using S3 set to "".
# $2..  Additional parameters passed on to the nextflow cli

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
executor.awscli = "/home/ec2-user/miniconda/bin/aws"
EOF

# AWS Batch places multiple jobs on an instance
# To avoid file path clobbering use the JobID and JobAttempt
# to create a unique path
GUID="$AWS_BATCH_JOB_ID/$AWS_BATCH_JOB_ATTEMPT"

if [ "$GUID" = "/" ]; then
    GUID=`date | md5sum | cut -d " " -f 1`
fi

mkdir -p /opt/work/$GUID
cd /opt/work/$GUID

# stage workflow definition
$NF_FILE=""
if [ ! -z "$NEXTFLOW_PROJECT" ]; then
    aws s3 sync --only-show-errors --exclude 'runs/*' --exclude '.*' $NEXTFLOW_PROJECT .
    NF_FILE=$(find . -maxdepth 1 -name "*.nf")
fi

echo "== Running Workflow =="
echo "nextflow run $NF_FILE $NEXTFLOW_PARAMS"
nextflow run $NF_FILE $NEXTFLOW_PARAMS