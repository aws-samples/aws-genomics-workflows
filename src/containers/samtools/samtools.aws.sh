#!/bin/bash
set -e

COMMAND=$1
REFERENCE_PREFIX=$2
REFERENCE_NAME=$3
SAMPLE_ID=$4
INPUT_PREFIX=$5
OUTPUT_PREFIX=${6:-$INPUT_PREFIX}

## AWS Batch places multiple jobs on an instance
## To avoid file path clobbering use the JobID and JobAttempt to create a unique path
GUID="$AWS_BATCH_JOB_ID/$AWS_BATCH_JOB_ATTEMPT"

if [ "$GUID" = "/" ]; then
    GUID=`date | md5sum | cut -d " " -f 1`
fi

REFERENCE_PATH=./$GUID/ref
INPUT_PATH=./$GUID/input
OUTPUT_PATH=./$GUID

mkdir -p $REFERENCE_PATH $INPUT_PATH

function index() {
    aws s3 cp \
        --no-progress \
        ${INPUT_PREFIX}/${SAMPLE_ID}.bam $INPUT_PATH
    
    samtools index \
        $INPUT_PATH/${SAMPLE_ID}.bam

    aws s3 sync \
        --no-progress \
        $INPUT_PATH $OUTPUT_PREFIX
}

function sort() {
    aws s3 cp \
        --no-progress \
        ${INPUT_PREFIX}/${SAMPLE_ID}.sam $INPUT_PATH
    
    samtools sort \
        -@ 8 \
        -o $OUTPUT_PATH/${SAMPLE_ID}.bam \
        $INPUT_PATH/${SAMPLE_ID}.sam

    aws s3 cp \
        --no-progress \
        ${OUTPUT_PATH}/${SAMPLE_ID}.bam $OUTPUT_PREFIX/${SAMPLE_ID}.bam
}

$COMMAND
