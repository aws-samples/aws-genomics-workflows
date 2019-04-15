#!/bin/bash

NEXTFLOW_SCRIPT=$1

# Create the default config using environment variables
# passed into the container
mkdir -p /opt/config
NF_CONFIG=/opt/config/nextflow.config

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

mkdir -p /opt/work/$GUID
cd /opt/work/$GUID

# stage workflow definition
aws s3 cp --no-progress $NEXTFLOW_SCRIPT .

NF_FILE=$(find . -name "*.nf")

echo "== Nextflow Configuration =="
cat $NF_CONFIG

echo "== Running Workflow =="
nextflow -c $NF_CONFIG run $NF_FILE
