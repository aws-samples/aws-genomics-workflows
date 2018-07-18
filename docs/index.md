# Large scale genomics workflows on AWS

Welcome! This tutorial walks through how to set up [Amazon Web Services](http://aws.amazon.com) ([AWS](http://aws.amazon.com)) products, such as [Amazon S3](http://aws.amazon.com/s3), [AWS Batch](http://aws.amazon.com/batch), etc., for running large scale genomics analyses. A typical genomics workflow is represented by the diagram below:

![Typical genomics workflow](./images/genomics-workflow.png)

Specifically, we want to create a system that handles packaging applications, executing individual tasks, and orchastrating the data between tasks.

## Prerequisites

We make a few assumptions on your experience:

1. You are familiar with the Linux command line
3. You can use SSH to log into a Linux server
2. You have a working AWS account
2. That account is able to create a [AWS Batch](https://aws.amazon.com/batch/) environment.

If you are completely new to AWS, we **highly recommend** going through the following two [AWS 10-Minute Tutorials](https://aws.amazon.com/getting-started/tutorials/).

1. **[Launch a Linux Virtual Machine](https://aws.amazon.com/getting-started/tutorials/launch-a-virtual-machine/)** - A tutorial which walks users through the process of starting a host on AWS, and configuring your own computer to connect over SSH.
2. **[Batch upload files to the cloud](https://aws.amazon.com/getting-started/tutorials/backup-to-s3-cli/)** - A tutorial on using the AWS Command Line Interface (CLI) to access Amazon S3.

The above tutorials will demonstrate the basics of AWS, as well as set up your development machine for working with AWS.

!!! tip
    We **strongly** recommend following the [IAM Security Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)for securing your root AWS account and IAM users.


## Setting up an AWS environment for genomics

There are several services at AWS that can be used for genomics. In this tutorial, we focus on [AWS Batch](http://aws.amazon.com/batch). AWS Batch itself is built on top of other AWS services, such as [Amazon EC2](https://aws.amazon.com/ec2) and [Amazon ECS](https://aws.amazon.com/ec2), and as such has a few requirements for escalated privileges to get started from scratch.

For example, you will need to be able to create some [IAM Roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html). AWS [Identity and Access Management (IAM)](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)
is a web service that helps you securely control access to AWS resources. You use IAM to control who is authenticated (signed in) and authorized (has permissions) to use resources.

We have provided some [CloudFormation](https://aws.amazon.com/cloudformation/) templates to make the initial environment setup less painful. We show how to use these in [step 2](#step-2).

!!! note
    If you are using a institutional account, it is likely that it does not  have administrative privileges, such as the IAM  [`AdministratorAccess` managed policy](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_managed-vs-inline.html).

    If this is the case, you will need to work with your account administrator to set up a AWS Batch environment for you. That means less work for you! Just point them at this guide, and hae them provide you with a [AWS Batch Job Queue ARN](https://docs.aws.amazon.com/batch/latest/userguide/job_queues.html), and a [Amazon S3 Bucket](https://docs.aws.amazon.com/AmazonS3/latest/dev/UsingBucket.html) that you can write results to. Move on to [Step 3](#step-3).

Assuming that you have the proper permissions, you are ready for [Setting up AWS Batch](aws-batch/configure-aws-batch-start.md).
