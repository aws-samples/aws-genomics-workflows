#  Deploying reference architecture for the Cromwell workflow management system on AWS

This reference architecture provides a set of YAML templates for deploying AWS resources, such as [AWS Batch](http://aws.amazon.com/batch/), for use with the [Cromwell](http://cromwell.readthedocs.io) workflow management system.

## [Step 0.](id:step-0) Prerequisites

If you have not already all of the following:

1. Created a AWS account
2. Created a IAM user with proper permissions
3. Configured the AWS CLI
3. Created and downloaded an EC2 Key Pair
4. Are able to SSH into a Linux host

Follow the [Prerequisites Guide](./doc/prereqs) to create these resources. All further instructions assume the above.

## [Step 1.](id:step-1) Create a customer AMI for genomics on AWS

Genomics, the main use case for Cromwell, is a data-heavy workload and requires some modification to the standard AWS Batch processing environment. In particular, we need to scale underlying instance storage that Tasks/Jobs run on top of to meet unpredictable runtime demands.

Follow the directions in the ["Creating a custom AMI for genomics"](./doc/cromwell-custom-ami) guide.

## [Step 2.](id:step-2) Launch and configure an AWS reference architecture for use with Cromwell

Once you have a custom AMI ID, such as `ami-a7a242da`, you  can launch the reference architecture CloudFormation stack in your account, using one of the links below. A full description of what is going on is described in the ["Deploying AWS Batch"](./doc/cromwell-aws-env-full) guide.


## [Step 3.](id:step-3) Configuring Cromwell for AWS

Deploying the full CloudFormation stack from [Step 2](#step-2) sets up a

## Overview

![AWS Reference Architecture](./images/refarch.png)

The repository consists of a set nested templates that deploy the following:

1. A tiered VPC with public and private subnets, spanning an AWS region.
2. A AWS Batch environment
3. A Linux bastion host to SSH into, preconfigured with Cromwell pre-configured to work with AWS Batch
