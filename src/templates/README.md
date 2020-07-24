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

## All-in-One ("AIO") Stacks

All-in-One stacks are provided for solutions that utilize:

* AWS Step-Functions
* Cromwell
* Nextflow

and build atop the Core Stack above.  They leverage the AWS VPC Quickstart to create a new VPC with subnets in 2 AZs and also include stacks specific to the orchestrator used:

| File | Description |
| :--- | :---------- |
| `step-functions/sfn-resources.template.yaml` | Creates an example AWS Step Functions state-machine and containers for an example genomics workflow using BWA, samtools, and bcftools. |
| `cromwell/cromwell-resources.template.yaml` | Creates an EC2 instance with Cromwell pre-installed and launched in "server" mode and an RDS Aurora Serverless database |
| `nextflow/nextflow-resources.template.yaml` | Creates a nextflow container and AWS Batch Job Definition for running nextflow |
