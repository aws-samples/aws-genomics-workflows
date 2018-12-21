# Introduction

Welcome!

This tutorial walks through how to use [Amazon Web Services](http://aws.amazon.com) ([AWS](http://aws.amazon.com)), such as [Amazon S3](http://aws.amazon.com/s3) and [AWS Batch](http://aws.amazon.com/batch), to run large scale genomics analyses.  Specifically, we want to create a system that handles packaging applications, executing individual tasks, and orchestrating the data between tasks.

Here you will learn how to:

1. Use S3 buckets to stage large genomics datasets as inputs and outputs from analysis pipelines
2. Create a job queues in AWS Batch to use for scalable and parallel job execution
3. Orchestrate genomics analysis workflows using native AWS services and 3rd party workflow engines

# Prerequisites

Throughout this tutorial we'll assume that you:

1. Are familiar with the Linux command line
2. Can use SSH to log into a Linux server
3. Have a access to an AWS account

If you are completely new to AWS, we **highly recommend** going through the following [AWS 10-Minute Tutorials](https://aws.amazon.com/getting-started/tutorials/) that will demonstrate the basics of AWS, as well as set up your development machine for working with AWS.

1. **[Launch a Linux Virtual Machine](https://aws.amazon.com/getting-started/tutorials/launch-a-virtual-machine/)** - A tutorial which walks users through the process of starting a host on AWS, and configuring your own computer to connect over SSH.
2. **[Batch upload files to the cloud](https://aws.amazon.com/getting-started/tutorials/backup-to-s3-cli/)** - A tutorial on using the AWS Command Line Interface (CLI) to access Amazon S3.

AWS has many services that can be used for genomics.  Here, we'll focus on [AWS Batch](http://aws.amazon.com/batch).

AWS Batch is a managed service that is built on top of other AWS services, such as [Amazon EC2](https://aws.amazon.com/ec2) and [Amazon Elasitc Container Service (ECS)](https://aws.amazon.com/ecs).  Thus, it has a few requirements for escalated privileges to get started from scratch.

For example, you will need to be able to create [IAM Roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html).

AWS [Identity and Access Management (IAM)](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)
is a service that helps you control access to AWS resources. You use IAM to control who is authenticated (signed in) and authorized (has permissions) to use resources.

!!! tip
    We **strongly** recommend following the [IAM Security Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) for securing your root AWS account and IAM users.

We have provided some [CloudFormation](https://aws.amazon.com/cloudformation/) templates to make the initial environment setup less painful.

!!! note
    If you are using a institutional account, it is likely that it does not have administrative privileges, such as the IAM  [`AdministratorAccess` managed policy](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_managed-vs-inline.html).

    If this is the case, you will need to work with your account administrator to set up a AWS Batch environment for you. That means less work for you! Just point them at this guide, and have them provide you with an [AWS Batch Job Queue ARN](https://docs.aws.amazon.com/batch/latest/userguide/job_queues.html), and a [Amazon S3 Bucket](https://docs.aws.amazon.com/AmazonS3/latest/dev/UsingBucket.html) that you can write results to.
