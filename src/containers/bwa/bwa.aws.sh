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

function mem() {
    aws s3 cp \
        --no-progress \
        --recursive \
        --exclude "*" \
        --include "${REFERENCE_NAME}.fasta*" \
        ${REFERENCE_PREFIX} $REFERENCE_PATH 

    ## sample files
    aws s3 cp \
        --no-progress \
        --recursive \
        --exclude "*" \
        --include "${SAMPLE_ID}*" \
        ${INPUT_PREFIX} $INPUT_PATH

    # command
    bwa mem -p \
        $REFERENCE_PATH/${REFERENCE_NAME}.fasta \
        $INPUT_PATH/${SAMPLE_ID}_1.fastq.gz \
        > $OUTPUT_PATH/${SAMPLE_ID}.sam

    # data staging
    aws s3 cp \
        --no-progress \
        $OUTPUT_PATH/${SAMPLE_ID}.sam ${OUTPUT_PREFIX}/${SAMPLE_ID}.sam

}

$COMMAND
