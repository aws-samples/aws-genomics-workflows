# Genomics Workflows on AWS

## Introduction

Welcome!

This guide walks through how to use [Amazon Web Services](https://aws.amazon.com) ([AWS](https://aws.amazon.com)), such as [Amazon S3](https://aws.amazon.com/s3) and [AWS Batch](https://aws.amazon.com/batch), to run large scale genomics analyses.

Here you will learn how to:

1. Use S3 buckets to stage large genomics datasets as inputs and outputs from analysis pipelines
2. Create job queues in AWS Batch to use for scalable parallel job execution
3. Orchestrate individual jobs into analysis workflows using native AWS services like [AWS Step Functions](https://aws.amazon.com/step-functions) and 3rd party workflow engines

If you're impatient and want to get something up and running immediately, head 
straight to the [TL;DR](tldr) section.  Otherwise, continue on for the full details.

## Prerequisites

Throughout this guide we'll assume that you:

1. Are familiar with the Linux command line
2. Can use SSH to access a Linux server
3. Have a access to an AWS account

If you are completely new to AWS, we **highly recommend** going through the following [AWS 10-Minute Tutorials](https://aws.amazon.com/getting-started/tutorials/) that will demonstrate the basics of AWS, as well as set up your development machine for working with AWS.

1. **[Launch a Linux Virtual Machine](https://aws.amazon.com/getting-started/tutorials/launch-a-virtual-machine/)** - A tutorial which walks users through the process of starting a host on AWS, and configuring your own computer to connect over SSH.
2. **[Batch upload files to the cloud](https://aws.amazon.com/getting-started/tutorials/backup-to-s3-cli/)** - A tutorial on using the AWS Command Line Interface (CLI) to access Amazon S3.

### AWS Account Access

AWS has many services that can be used for genomics.  Here, we will build core architecture with [AWS Batch](https://aws.amazon.com/batch), a managed service that is built on top of other AWS services, such as [Amazon EC2](https://aws.amazon.com/ec2) and [Amazon Elastic Container Service (ECS)](https://aws.amazon.com/ecs).  Along the way, we'll leverage some advanced capabilities that need escalated (administrative) privileges to implement.  For example, you will need to be able to create [Roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) via AWS [Identity and Access Management (IAM)](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html), a service that helps you control who is authenticated (signed in) and authorized (has permissions) to use AWS resources.

!!! tip
    We **strongly** recommend following the [IAM Security Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) for securing your root AWS account and IAM users.

!!! note
    If you are using a institutional account, it is likely that you do not have administrative privileges, i.e. the IAM [AdministratorAccess](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_managed-vs-inline.html) managed policy is not attached to your IAM User or Role, and you won't be able to attach it yourself.

    If this is the case, you will need to work with your account administrator to get things set up for you. Refer them to this guide, and have them provide you with an [AWS Batch Job Queue ARN](https://docs.aws.amazon.com/batch/latest/userguide/job_queues.html), and a [Amazon S3 Bucket](https://docs.aws.amazon.com/AmazonS3/latest/dev/UsingBucket.html) that you can write results to.
