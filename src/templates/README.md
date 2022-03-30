# Genomics Workflows on AWS CloudFormation templates

Contained herein are CloudFormation templates for creating AWS resources for working with large-scale biomedical data - e.g. genomics.

## Core Stack

Templates in `gwfcore` are the "core" stack.  The root template is:

| File | Description |
| :--- | :---------- |
| `gwfcore-root.template.yaml` | Root stack that invokes nested stacks (see below) |

Nested stacks are as follows and listed in order of creation:

| File | Description |
| :--- | :---------- |
| `gwfcore-s3.template.yaml` | Creates an S3 bucket for storing installed artifacts and workflow input and output data |
| `gwfcore-code.template.yaml` | Creates and installs code and artifacts used to run subsequent templates and provision EC2 instances |
| `gwfcore-launch-template.template.yaml` | Creates an EC2 Launch Template used in AWS Batch Compute Environments |
| `gwfcore-iam.template.yaml` | Creates IAM roles for AWS Batch resources |
| `gwfcore-batch.template.yaml` | Creates AWS Batch Job Queues and Compute Environments for job execution |

Optional Stacks
| File | Description |
| :--- | :---------- |
| `gwfcore-fsx.template.yaml` | Creates an FSx for Lustre file system (only Persistent 1 type) mapped to the S3 bucket for storing workflow input, output and reference data. Refer Note section at the bottom. |
| `gwfcore-efs.template.yaml` | Creates an EFS file system for storing workflow input, output and reference data |

## Orchestration Stacks

The following Stacks provide solutions that utilize:

* AWS Step-Functions
* Cromwell
* Nextflow

They build atop the Core Stack above. They provide the additional resources needed to run each orchestrator.

| File | Description |
| :--- | :---------- |
| `step-functions/sfn-resources.template.yaml` | Creates an example AWS Step Functions state-machine and containers for an example genomics workflow using BWA, samtools, and bcftools. |
| `cromwell/cromwell-resources.template.yaml` | Creates an EC2 instance with Cromwell pre-installed and launched in "server" mode and an RDS Aurora Serverless database |
| `nextflow/nextflow-resources.template.yaml` | Creates a Nextflow container and AWS Batch Job Definition for running Nextflow |


Note : As System Manager Parameter Store is being used, make sure to increase the throughput from console. To do that follow below :
AWS Systems Manager -> Parameter Store -> Settings -> Parameter Store throughput -> paid tier/higher throughput limit.