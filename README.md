# Using Cromwell with AWS Batch

This repository contains everything you need to get started using [AWS Batch](TODO) with the [Cromwell](TODO) workflow management system.

## Step 0. Creating a basic AWS environment

### Step 0.1 A AWS account

If you do not have one already, [create an AWS Account](https://portal.aws.amazon.com/billing/signup#/start) and an [AWS Identity and Access Management (IAM)](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html) user for use with Cromwell.


:fire:  _WARNING_
We **strongly** recommend following the [IAM Security Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) for securing your root AWS account and IAM users.

### Step 0.2 Setting up a Amazon Virtual Private Cloud (VPC)

Amazon Virtual Private Cloud ([Amazon VPC](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Introduction.html)) enables you to launch AWS resources into a virtual network that you've defined. All users will need to designate a VPC to launch compute resources into.

While users are able to leverage a [default VPC and Subnets](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/default-vpc.html), we **strongly** recommend a more advanced setup that leverages private (not internet accessible) subnets and additional layers of security such as network Access Control Lists. There are [AWS Quickstart](https://aws.amazon.com/quickstart/) reference architectures for a [Modular and Scalable VPC Architecture](https://aws.amazon.com/quickstart/architecture/vpc/) serves this requirement.

:bulb:  _TIP_
You may also want to review the  [HIPAA on AWS Enterprise Accelerator](https://aws.amazon.com/quickstart/architecture/accelerator-hipaa/) for additional security best practices such as:

* Basic AWS Identity and Access Management (IAM) configuration with custom (IAM) policies, with associated groups, roles, and instance profiles
* Standard, external-facing Amazon Virtual Private Cloud (Amazon VPC) Multi-AZ architecture with separate subnets for different application tiers and private (back-end) subnets for application and database
* Amazon Simple Storage Service (Amazon S3) buckets for encrypted web content, logging, and backup data
* Standard Amazon VPC security groups for Amazon Elastic Compute Cloud (Amazon EC2) instances and load balancers used in the sample application stack
* A secured bastion login host to facilitate command-line Secure Shell (SSH) access to Amazon EC2 instances for troubleshooting and systems administration activities
* Logging, monitoring, and alerts using AWS CloudTrail, Amazon CloudWatch, and AWS Config rules
!!!END

## Step 1. Creating a custom AMI for genomics

Genomics, the main use case for Cromwell, is a data-heavy workload and requires some modification to the standard AWS Batch processing environment. In particular, we need to scale instance storage to meet unpredictable runtime demands

## Step 2. Configuring AWS Batch

## Step 3. Configuring Cromwell
