#!/bin/bash
# Universal entrypoint script for containerized tooling for use with AWS Batch
# that handles data staging of predefined inputs and outputs.
#
# Environment Variables
#   JOB_WORKFLOW_NAME
#       Optional
#       Name of the parent workflow for this job.  Used with JOB_WORKFLOW_EXECUTION_ID
#       to generate a unique prefix for workflow outputs.
#
#   JOB_WORKFLOW_EXECUTION_ID
#       Optional
#       Unique identifier for the current workflow run.  Used with JOB_WORKFLOW_NAME
#       to generate a unique prefix for workflow outputs.
#
#   JOB_AWS_CLI_PATH
#       Required if staging data from S3
#       Default: /opt/miniconda/bin
#       Path to add to the PATH environment variable so that the AWS CLI can be
#       located.  Use this if bindmounting the AWS CLI from the host and it is
#       packaged in a self-contained way (e.g. not needing OS/distribution 
#       specific shared libraries).  The AWS CLI installed with `conda` is
#       sufficiently self-contained.  Using a standard python virtualenv does
#       not work.
# 
#   JOB_DATA_ISOLATION
#       Optional
#       Default: null
#       Set to 1 if container will need to use an isolated data space - e.g.
#       it will operate in a volume mounted from the host for scratch
#
#   JOB_INPUTS
#       Optional
#       Default: null
#       A space delimited list of s3 object urls - e.g.:
#           s3://{prefix1}/{key_pattern1} [s3://{prefix2}/{key_pattern2} [...]]
#       for files that the job will use as inputs
#
#   JOB_OUTPUTS
#       Optional
#       Default: null
#       A space delimited list of files - e.g.:
#           file1 [file2 [...]]
#       that the job generates that will be retained - i.e. transferred back to S3
#
#   JOB_OUTPUT_PREFIX
#       Required if JOB_OUTPUTS need to be stored on S3
#       Default: null
#       S3 location (e.g. s3://bucket/prefix) were job outputs will be stored

set -e  # exit on error

if [[ $JOB_VERBOSE ]]; then
    set -x  # enable echo
fi

DEFAULT_AWS_CLI_PATH=/opt/aws-cli/bin
AWS_CLI_PATH=${JOB_AWS_CLI_PATH:-$DEFAULT_AWS_CLI_PATH}
PATH=$PATH:$AWS_CLI_PATH

# ensure that JOB_INPUT_PREFIX is fully evaluated if present
if [[ $JOB_INPUT_PREFIX ]]; then
    JOB_INPUT_PREFIX=`echo $JOB_INPUT_PREFIX | envsubst`
fi

if [[ $JOB_DATA_ISOLATION && $JOB_DATA_ISOLATION == 1 ]]; then
    ## AWS Batch places multiple jobs on an instance
    ## To avoid file path clobbering if using a host mounted scratch use the JobID 
    ## and JobAttempt to create a unique path
    
    if [[ $AWS_BATCH_JOB_ID ]]; then
        GUID="$AWS_BATCH_JOB_ID/$AWS_BATCH_JOB_ATTEMPT"
    else
        GUID=`date | md5sum | cut -d " " -f 1`
    fi

    mkdir -p $GUID
    cd $GUID
fi

function stage_in() (
    # loops over list of inputs (patterns allowed) which are a space delimited list
    # of s3 urls:
    #   s3://{prefix1}/{key_pattern1} [s3://{prefix2}/{key_pattern2} [...]]
    # uses the AWS CLI to download objects

    # `noglob` option is needed so that patterns are not expanded against the 
    # local filesystem. this setting is local to the function
    set -o noglob

    for item in "$@"; do
        item=`echo $item | envsubst`
        if [[ $item =~ ^s3:// ]]; then
            local item_key=`basename $item`
            local item_prefix=`dirname $item`

            echo "[input] remote: $item ==> ./$item_key"
            
            aws s3 cp \
                --no-progress \
                --recursive \
                --exclude "*" \
                --include "${item_key}" \
                ${item_prefix} .

        else
            echo "[input] local: $item"

        fi
    done
)

function stage_out() (
    # loops over list of outputs which are a space delimited list of filenames:
    #   file1 [file2 [...]]
    # uses the AWS CLI to upload objects

    for item in "$@"; do
        if [ ! -f $item ]; then
            # If an expected output is not found it is generally considered an
            # error.  To suppress this error when using glob expansion you can 
            # set the `nullglob` option (`shopt -s nullglob`)
            echo "[output] ERROR: $item does not exist" 1>&2
            exit 1
        else
            if [[ $JOB_OUTPUT_PREFIX && $JOB_OUTPUT_PREFIX =~ ^s3:// ]]; then
                local item_key=`basename $item`
                local output_prefix=$JOB_OUTPUT_PREFIX

                if [[ $JOB_WORKFLOW_NAME && $JOB_WORKFLOW_EXECUTION_ID ]]; then
                    local output_prefix=$output_prefix/$JOB_WORKFLOW_NAME/$JOB_WORKFLOW_EXECUTION_ID
                fi

                echo "[output] remote: ./$item ==> $output_prefix/${item_key}"

                aws s3 cp \
                    --no-progress \
                    ./$item $output_prefix/${item_key}

            elif [[ $JOB_OUTPUT_PREFIX && ! $JOB_OUTPUT_PREFIX =~ ^s3:// ]]; then
                echo "[output] ERROR: unsupported remote output destination $JOB_OUTPUT_PREFIX" 1>&2

            else
                echo "[output] local: ./$item"

            fi
        fi
    done
)

# Command is specified in the JobSubmission container overrides.
# gives the user flexibility to specify tooling options as needed.
#
# Note that AWS Batch has an implicit 8kb limit on the amount of data allowed in
# container overrides, which includes environment variable data.
COMMAND=`echo "$*" | envsubst`

printenv
stage_in $JOB_INPUTS

echo "[command]: $COMMAND"
bash -c "$COMMAND"


stage_out $JOB_OUTPUTS

