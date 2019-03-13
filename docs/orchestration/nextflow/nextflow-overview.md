# Nextflow on AWS Batch

![Nextflow on AWS](./images/nextflow-on-aws-infrastructure.png)

[Nextflow](https://www.nextflow.io) is a reactive workflow framework and DSL developed by the [Comparative Bioinformatics group](https://www.crg.eu/en/programmes-groups/notredame-lab) at the Barcelona [Centre for Genomic Regulation (CRG)](http://www.crg.eu/) that enables scalable and reproducible scientific workflows using software containers.

## Full Stack Deployment (TL;DR)

The following CloudFormation template will launch a EC2 instance pre-configured for using Nextflow.

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | -- |
{{ cfn_stack_row("Nextflow All-in-One", "Nextflow", "nextflow/nextflow-aio.template.yaml", "Create all resources needed to run Nextflow on AWS: an S3 Bucket for data, S3 Bucket for nextflow config and workflows, AWS Batch Environment, and Nextflow head node job definition and job role") }}

When the above stack is complete, you will have a preconfigured Batch Job Definition that you can use to launch Nextflow pipelines.  Skip to the [Running a workflow](#running-a-workflow) section below to learn how.

## Requirements

To get started using Nextflow on AWS you'll need the following setup in your AWS account:

* The core set of resources (S3 Bucket, IAM Roles, AWS Batch) described in the [Getting Started](../../../core-env/introduction) section.
* A containerized `nextflow` executable that pulls configuration and workflow definitions from S3
* The AWS CLI installed in job instances using `conda`
* A Batch Job Definition that runs a Nextflow head node
* An IAM Role for the Nextflow head node job that allows it access to AWS Batch
* (optional) An S3 Bucket to store your Nextflow workflow definitions

The last four items above are created by the following CloudFormation template:

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | -- |
{{ cfn_stack_row("Nextflow Resources", "NextflowResources", "nextflow/nextflow-resources.template.yaml", "Create Nextflow specific resources needed to run on AWS: an S3 Bucket for nextflow workflow scripts, AWS Batch Job Definition for a Nextflow head node, and an IAM role for the nextflow head node job") }}

### Nextflow container

To create a container with the `nextflow` executable that pulls a workflow script from S3, you can use a `Dockerfile` like the one below:

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

where the entrypoint script is:

```bash
#!/bin/bash

NEXTFLOW_SCRIPT=$1

# Create the default config using environment variables
# passed into the container
mkdir -p /opt/config
NF_CONFIG=/opt/config/nextflow.cnfig

cat << EOF > $NF_CONFIG
workDir = "$AWS_WORKDIR"
process.executor = "awsbatch"
process.queue = "$AWS_BATCH_JOB_QUEUE"
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

nextflow -c $NF_CONFIG run $NF_FILE
```

### Job instance AWS CLI

Nextflow uses the [AWS CLI](https://aws.amazon.com/cli/) to stage data in / out for a workflow task.  This AWS CLI can be either installed on the host instance that task containers run on, or included in the task container.

Adding the AWS CLI to an existing containerized tool requires rebuilding the image to include it.  Assuming your tool's container image is based on CentOS, this would require a Dockerfile like so:

```Dockerfile
FROM myoriginalcontainer
RUN yum install -y awscli

ENTRYPOINT ["mytool"]
```

If you have many tools in your pipeline, rebuilding all of their images and keeping them up to date may not be ideal.

Using a version installed on the host instance means you can use pre-existing containers.  The caveat here is that the AWS CLI must be installed on the host using `conda`, which packages the `aws` command with a corresponding Python environment.

Installing the AWS CLI via `conda` is easily handled by running a `UserData` script in an EC2 Launch Template.  For example:

```bash
yum install -y bzip2 wget
USER=/home/ec2-user

wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -f -p $USER/miniconda
$USER/miniconda/bin/conda install -c conda-forge -y awscli

chown -R ec2-user:ec2-user $USER/miniconda

rm Miniconda3-latest-Linux-x86_64.sh
```

This is all handled automatically in the CloudFormation templates above.

### Batch job definition

```json
{
    "jobDefinitionName": "nextflow",
    "jobDefinitionArn": "arn:aws:batch:us-west-2:<account-number>:job-definition/nextflow:1",
    "revision": 1,
    "status": "ACTIVE",
    "type": "container",
    "parameters": {
        "NextflowScript": "s3://<bucket-name>/nextflow/workflow.nf"
    },
    "containerProperties": {
        "image": "<dockerhub-user>/nextflow:latest",
        "vcpus": 2,
        "memory": 1024,
        "command": [
            "Ref::NextflowScript"
        ],
        "volumes": [
            {
                "host": {
                    "sourcePath": "/scratch"
                },
                "name": "scratch"
            }
        ],
        "environment": [
            {
                "name": "AWS_BATCH_JOB_QUEUE",
                "value": "<jobQueueArn>"
            },
            {
                "name": "AWS_WORKDIR",
                "value": "s3://<bucket-name>/runs"
            }
        ],
        "mountPoints": [
            {
                "containerPath": "/opt/work",
                "sourceVolume": "scratch"
            }
        ],
        "ulimits": []
    }
}
```

### Nextflow IAM Role

Nextflow needs to be able to create and submit Batch Job Defintions and Batch Jobs, and read workflow script files in an S3 bucket. These permissions are provided via a Job Role associated with the Job Definition.  Policies for this role would look like the following:

#### Nextflow-Batch-Access

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

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::<script-bucket-name>",
                "arn:aws:s3:::<script-bucket-name>/*",
                "arn:aws:s3:::<data-bucket-name>",
                "arn:aws:s3:::<data-bucket-name>/*"
            ],
            "Effect": "Allow"
        }
    ]
}
```

## A Nextflow S3 Bucket

The containerized version of `nextflow` above reads a `*.nf` script from an S3 bucket.  This bucket can either be the same one that your workflow inputs and outputs are stored (e.g. in a separate folder therein), or it can be another bucket entirely.

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

The `process` definitions in Nextflow scripts should include a couple key parts in when running on AWS Batch:

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


### Running the workflow

To run a workflow you submit a `nextflow` Batch job to the appropriate Batch Job Queue via:

* the AWS Batch Console
* or the command line with the AWS CLI

This is what starting a workflow via the AWS CLI would look like:

```bash
aws batch submit-job \
    --job-name run-workflow-nf \
    --job-queue <queue-name> \
    --job-definition nextflow \
    --parameters \
        "NextflowScript=s3://path/to/workflow.nf"
```

After submitting a workflow, you can monitor the progress of tasks via the AWS Batch console.