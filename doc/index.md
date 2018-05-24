# Creating a AWS environment for Cromwell

Welcome! This tutorial walks through how to set up Cromwell to leverage an AWS environment for running analyses. We make a few assumptions:


1. You are familiar with the Linux command line
3. You can use SSH to log into a Linux server
2. You have a working AWS account
2. That account is able to create a [AWS Batch](https://aws.amazon.com/batch/) environment.

If you are completely new to AWS, we **highly recommend** going through the following two [AWS 10-Minute Tutorials](https://aws.amazon.com/getting-started/tutorials/).

1. **[Launch a Linux Virtual Machine](https://aws.amazon.com/getting-started/tutorials/launch-a-virtual-machine/)** - A tutorial which walks users through the process of starting a host on AWS, and configuring your own computer to connect over SSH.
2. **[Batch upload files to the cloud](https://aws.amazon.com/getting-started/tutorials/backup-to-s3-cli/)** - A tutorial on using the AWS Command Line Interface (CLI) to access Amazon S3.

The above tutorials will demonstrate the basics of AWS, as well as set up your development machine for working with AWS.


<table>
<tr><th>
:fire:  <span style="color: red;" >WARNING</span>
</th><td>
We <b>strongly</b> recommend following the
<a href='https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html'>IAM Security Best Practices</a> for securing your root AWS account and IAM users.
</td></tr>
</table>


AWS Batch itself is built on top of other AWS services, such as [Amazon EC2](https://aws.amazon.com/ec2) and [Amazon ECS](https://aws.amazon.com/ec2), and as such has a few requirements for escalated privileges to get started from scratch.  For example, you will need to be able to create some [IAM Roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html). AWS [Identity and Access Management (IAM)](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)
is a web service that helps you securely control access to AWS resources. You use IAM to control who is authenticated (signed in) and authorized (has permissions) to use resources.

_Luckily_, we have provided some templates to make the initial environment setup less painful.

<table>
<tr><th>
:bulb:  <span style="color: orange;" >TIP</span>
</th><td>
If you are using some institutionally controlled account with restricted access, you will need to point them at this guide to enable you to use Cromwell on AWS.
</td></tr>
</table>

## [Step 1.](id:step-1) Setting up a custom AMI for genomics workflows

Genomics, the main use case for Cromwell, is a data-heavy workload and requires some modification to the standard AWS Batch processing environment. In particular, we need to scale underlying instance storage that Tasks/Jobs run on top of to meet unpredictable runtime demands.

**[Create a custom AMI for use with AWS Batch](./create-custom-ami)**

## [Step 2.](id:step-2) Setting up AWS Batch

Once you have a custom AMI (or if you do not need one and can use the default), it is time to set up AWS Batch.

**[Setting up a new AWS Batch environment](./configure-aws-batch)**

## [Step 3.](id:step-3) Configuring Cromwell to use your AWS Batch environment

Now that we have a AWS Batch environment (that may utilize the custom AMI for a [Compute Resource AMI](https://docs.aws.amazon.com/batch/latest/userguide/compute_resource_AMIs.html)), we can now configure a Cromwell installation to use it.

**[Configure Cromwell to use AWS Batch](./configure-cromwell)**
