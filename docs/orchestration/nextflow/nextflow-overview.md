# Nextflow on AWS Batch

![Nextflow on AWS](./images/nextflow-on-aws-infrastructure.png)

[Nextflow](https://www.nextflow.io) is a reactive workflow framework and domain specific language (DSL) developed by the [Comparative Bioinformatics group](https://www.crg.eu/en/programmes-groups/notredame-lab) at the Barcelona [Centre for Genomic Regulation (CRG)](http://www.crg.eu/) that enables scalable and reproducible scientific workflows using software containers.

Nextflow can be run either locally or on a dedicated EC2 instance.  The latter is preferred if you have long running workflows - with the caveat that you are responsible for stopping the instance when your workflow is complete.  The architecture presented in this guide demonstrates how you can run Nextflow using AWS Batch in a managed and cost effective fashion.

## Full Stack Deployment

The following CloudFormation template will launch an EC2 instance pre-configured for using Nextflow.

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | -- |
{{ cfn_stack_row("Nextflow All-in-One", "Nextflow", "nextflow/nextflow-aio.template.yaml", "Create all resources needed to run Nextflow on AWS: an AWS S3 Bucket for data, S3 Bucket for nextflow config and workflows, AWS Batch Environment, and Nextflow head node job definition and job role") }}

When the above stack is complete, you will have a preconfigured Batch Job Definition that you can use to launch Nextflow pipelines.  Skip to the [Running a workflow](#running-a-workflow) section below to learn how.

## Requirements

To get started using Nextflow on AWS you'll need the following setup in your AWS account:

* The core set of resources (S3 Bucket, IAM Roles, AWS Batch) described in the [Getting Started](../../../core-env/introduction) section.
* A containerized `nextflow` executable that pulls configuration and workflow definitions from S3
* The AWS CLI installed in job instances using `conda`
* A Batch Job Definition that runs a Nextflow head node
* An IAM Role for the Nextflow head node job that allows it access to AWS Batch
* (optional) An S3 Bucket to store your Nextflow workflow definitions

The last five items above are created by the following CloudFormation template:

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | -- |
{{ cfn_stack_row("Nextflow Resources", "NextflowResources", "nextflow/nextflow-resources.template.yaml", "Create Nextflow specific resources needed to run on AWS: an S3 Bucket for nextflow workflow scripts, Nextflow container, AWS Batch Job Definition for a Nextflow head node, and an IAM role for the nextflow head node job") }}

### Nextflow container

For AWS Batch to run Nextflow as a Batch Job, it needs to be containerized.  The template above will build a container using the methods described below which includes adding capabilities to automatically configure Nextflow and run workflow scripts in S3.  If you want to add specialized capabilities or require a particular version of Nextflow, you can modify the source code to best suit your needs.

To create such a container, you can use a `Dockerfile` like the one below:

```Dockerfile
FROM centos:7

RUN yum update -y \
 && yum install -y \
    curl \
    java-1.8.0-openjdk \
    awscli \
 && yum clean -y all

ENV JAVA_HOME /usr/lib/jvm/jre-openjdk/

WORKDIR /opt/inst
RUN curl -s https://get.nextflow.io | bash
RUN mv nextflow /usr/local/bin

COPY nextflow.aws.sh /opt/bin/nextflow.aws.sh
RUN chmod +x /opt/bin/nextflow.aws.sh

WORKDIR /opt/work
ENTRYPOINT ["/opt/bin/nextflow.aws.sh"]
```

!!! note
    If you are trying to keep your container image as small as possible, keep in mind that Nextflow relies on basic linux tools such as `awk`, `bash`, `ps`, `date`, `sed`, `grep`, `egrep`, and `tail` which may need to be installed on extra minimalist base images like `alpine`.

The script used for the entrypoint is shown below. The first parameter should be a Nextflow "project".  Nextflow supports pulling projects directly from Git repositories.  This script also allows for projects to be specified as an S3 URI - a bucket and folder therein where you have staged your Nextflow scripts and supporting files (like additional config files). Any additional parameters are passed along to the Nextflow executable.  Also, the script automatically configures some Nextflow values based on environment variables set by AWS Batch.

```bash
#!/bin/bash

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
```

The `AWS_BATCH_JOB_ID` and `AWS_BATCH_JOB_ATTEMPT` are [environment variables that are automatically provided](https://docs.aws.amazon.com/batch/latest/userguide/job_env_vars.html) to all AWS Batch jobs.  The `NF_WORKDIR`, `NF_LOGSDIR`, and `NF_JOB_QUEUE` variables are ones set by the Batch Job Definition ([see below](#batch-job-definition)).

### Job instance AWS CLI

Nextflow uses the [AWS CLI](https://aws.amazon.com/cli/) to stage input and output data for tasks.  The AWS CLI can either be installed in the task container or on the host instance that task containers run on.

Adding the AWS CLI to an existing containerized tool requires rebuilding the image to include it.  Assuming your tool's container image is based on CentOS, this would require a Dockerfile like so:

```Dockerfile
FROM myoriginalcontainer
RUN yum install -y awscli

ENTRYPOINT ["mytool"]
```

If you have many tools in your pipeline, rebuilding all of their images and keeping them up to date may not be ideal.

Using a version installed on the host instance means you can use pre-existing containers.  The caveat here is that the AWS CLI must be installed on the host using `conda`, which packages the `aws` command with a corresponding Python environment.

Installing the AWS CLI via `conda` can be done via a `UserData` script in an EC2 Launch Template.  For example:

```bash
yum install -y bzip2 wget
USER=/home/ec2-user

wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -f -p $USER/miniconda
$USER/miniconda/bin/conda install -c conda-forge -y awscli

chown -R ec2-user:ec2-user $USER/miniconda

rm Miniconda3-latest-Linux-x86_64.sh
```

### Batch job definition

An AWS Batch Job Definition for the containerized Nextflow described above is shown below.

```json
{
    "jobDefinitionName": "nextflow",
    "jobDefinitionArn": "arn:aws:batch:<region>:<account-number>:job-definition/nextflow:1",
    "type": "container",
    "parameters": {},
    "containerProperties": {
        "image": "<account-number>.dkr.ecr.<region>.amazonaws.com/nextflow:latest",
        "vcpus": 2,
        "memory": 1024,
        "command": [],
        "jobRoleArn": "<nextflowJobRoleArn>",
        "volumes": [],
        "environment": [
            {
                "name": "NF_LOGSDIR",
                "value": "s3://<bucket>/_nextflow/logs"
            },
            {
                "name": "NF_JOB_QUEUE",
                "value": "<jobQueueArn>"
            },
            {
                "name": "NF_WORKDIR",
                "value": "s3://<bucket>/_nextflow/runs"
            }
        ],
        "mountPoints": [],
        "ulimits": [],
        "resourceRequirements": []
    }
}
```

The `<nextflowJobRoleArn>` is described below.

### Nextflow IAM Role

Nextflow needs to be able to create and submit Batch Job Defintions and Batch Jobs, and read workflow logs and session information from an S3 bucket. These permissions are provided via a Job Role associated with the Job Definition.  Policies for this role would look like the following:

#### Nextflow-Batch-Access

This policy gives **full** access to AWS Batch.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "batch:*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
```

#### Nextflow-S3Bucket-Access

This policy gives **full** access to the buckets used to store workflow data and Nextflow session metadata.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::<nextflow-bucket-name>",
                "arn:aws:s3:::<nextflow-bucket-name>/*",
                "arn:aws:s3:::<data-bucket-name>",
                "arn:aws:s3:::<data-bucket-name>/*"
            ],
            "Effect": "Allow"
        }
    ]
}
```

## A Nextflow S3 Bucket

Because running as a container will be an ephemeral process, the containerized version of `nextflow` stores workflow session information in S3 using paths described by `NF_WORKDIR` and `NF_LOGSDIR` environment variables.  These allow you to use Nextflow's `-resume` flag to restart a workflow that was previously interrupted at the step it left off at.

This bucket can be independent of the S3 bucket used to store workflow input and output data if necessary.

## Running a workflow

### Configuration

The entrypoint script for the `nextflow` container above generates a default config file automatically that looks like the following:

```groovy
// where workflow logs are written
workDir = 's3://<s3-nextflow-bucket>/<s3-prefix>/runs'

process.executor = 'awsbatch'
process.queue = '<batch-job-queue>'

// AWS CLI tool is installed via the instance launch template
executor.awscli = '/home/ec2-user/miniconda/bin/aws'
```

The script will replace `<s3-nextflow-bucket>`, `<s3-prefix>`, and `<batch-job-queue>` with values appropriate for your environment.

### Workflow process definitions

The `process` definitions in Nextflow scripts should include a couple key parts for running on AWS Batch:

* the `container` directive
* `cpus` and `memory` directives to define resource that will be used by Batch Jobs

An example defintion for a simple "Hello World" process is shown below:

```groovy
texts = Channel.from("AWS", "Nextflow")

process hello {
    // directives
    // a container images is required
    container "ubuntu:latest"

    // compute resources for the Batch Job
    cpus 1
    memory '512 MB'

    input:
    val text from texts

    output:
    file 'hello.txt'

    """
    echo "Hello $text" > hello.txt
    """
}
```

For each process in your workflow, Nextflow will create a corresponding Batch Job Definition, which it will re-use for subsequent workflow runs.  The process defined above will create a Batch Job Definition called `nf-ubuntu-latest` that looks like:

```json
{
    "jobDefinitionName": "nf-ubuntu-latest",
    "jobDefinitionArn": "arn:aws:batch:<region>:<account-number>:job-definition/nf-ubuntu-latest:1",
    "revision": 1,
    "status": "ACTIVE",
    "type": "container",
    "parameters": {
        "nf-token": "43869867b5fbae16fa7cfeb5ea2c3522"
    },
    "containerProperties": {
        "image": "ubuntu:latest",
        "vcpus": 1,
        "memory": 1024,
        "command": [
            "true"
        ],
        "volumes": [
            {
                "host": {
                    "sourcePath": "/home/ec2-user/miniconda"
                },
                "name": "aws-cli"
            }
        ],
        "environment": [],
        "mountPoints": [
            {
                "containerPath": "/home/ec2-user/miniconda",
                "readOnly": true,
                "sourceVolume": "aws-cli"
            }
        ],
        "ulimits": []
    }
}
```

You can customize these job definitions to incorporate additional environment variables or volumes/mount points as needed.

!!! note
    As of Nextflow 19.07 you can use the `aws.batch.volumes` config option to define additional volumes and mount points.

!!! important
    Instances provisioned using the Nextflow specific EC2 Launch Template configure `/var/lib/docker` in the host instance to use automatically [expandable scratch space](../../../core-env/create-custom-compute-resources/), allowing containerized jobs to stage as much data as needed without running into disk space limits.

### Running the workflow

To run a workflow you submit a `nextflow` Batch job to the appropriate Batch Job Queue via:

* the AWS Batch Console
* or the command line with the AWS CLI

This is what starting a workflow via the AWS CLI would look like using Nextflow's built-in "hello-world" workflow:

```bash
aws batch submit-job \
    --job-name nf-hello \
    --job-queue <queue-name> \
    --job-definition nextflow \
    --container-overrides command=hello
```

After submitting a workflow, you can monitor the progress of tasks via the AWS Batch console.
For the "Hello World" workflow above you will see five jobs run in Batch - one for the head node, and one for each `Channel` text as it goes through the `hello` process.

For a more complex example, you can try the following, which will run the [RNASeq workflow](https://nf-co.re/rnaseq) developed by the [NF-Core project](https://nf-co.re/) against data in the [1000 Genomes AWS Public Dataset](https://registry.opendata.aws/1000-genomes/):

```bash
aws batch submit-job \
    --job-name nf-core-rnaseq \
    --job-queue <queue-name> \
    --job-definition nextflow \
    --container-overrides command=nf-core/rnaseq,\
"--reads","'s3://1000genomes/phase3/data/HG00243/sequence_read/SRR*_{1,2}.filt.fastq.gz'",\
"--genome","GRCh37",\
"--skip_qc"
```

For the nf-core example "rnaseq" workflow you will see 11 jobs run in Batch over the course of a couple hours - the head node will last the whole duration of the pipeline while the others will stop once their step is complete. You can look at the CloudWatch logs for the head node job to monitor workflow progress. Note the additional single quotes wrapping the 1000genomes path.
