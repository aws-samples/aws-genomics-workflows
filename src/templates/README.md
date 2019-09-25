# Genomics Workflows on AWS CloudFormation templates

Contained herein are CloudFormation templates for creating AWS resources for working with large-scale biomedical data - e.g. genomics.

## Core Stack

Templates at the root level represent the "core" stack.  The root template is:

| File | Description |
| :--- | :---------- |
| `aws-genomics-root-novpc.template.yaml` | Root stack that invokes nested stacks (see below) |

Nested stacks are as follows and listed in order of creation:

| File | Description |
| :--- | :---------- |
| `aws-genomics-s3.template.yaml` | Creates an S3 bucket for storing workflow input and output data |
| `aws-genomics-launch-template.template.yaml` | Creates an EC2 Launch Template used in AWS Batch Compute Environments |
| `aws-genomics-iam.template.yaml` | Creates IAM roles for AWS Batch resources |
| `aws-genomics-batch.template.yaml` | Creates AWS Batch Job Queues and Compute Environments for job execution |

## All-in-One ("AIO") Stacks

All-in-One stacks are provided for solutions that utilize:

* AWS Step-Functions
* Cromwell
* Nextflow

and build atop the Core Stackk above.  They also include additional stacks specific to the solution:

| File | Description |
| :--- | :---------- |
| `step-functions/sfn-example.template.yaml` | Creates an example AWS Step Functions state-machine and containers for an example genomics workflow using BWA, samtools, and bcftools. |
| `cromwell/cromwell-server.template.yaml` | Creates an EC2 instance with Cromwell pre-installed and launched in "server" mode |
| `nextflow/nextflow-resources.template.yaml` | Creates a nextflow container and AWS Batch Job Definition for running nextflow |
