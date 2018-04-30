# Using Cromwell with AWS Batch

This repository contains everything you need to get started using [AWS Batch](TODO) with the [Cromwell](TODO) workflow management system.

## Step 0. Creating a basic AWS environment

### Step 0.1. A AWS account

If you do not have one already, [create an AWS Account](https://portal.aws.amazon.com/billing/signup#/start).

### Step 0.2. Setting up the AWS IAM user and AWS CLI

Next we need to set up your development environment, which means creating an  [AWS Identity and Access Management (IAM)](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html) user for use with Cromwell, and the [AWS Command Line Interface (AWS CLI)]. At the same time w

The easiest way to accomplish this follow [Step 1](https://aws.amazon.com/getting-started/tutorials/backup-to-s3-cli/#Step_1\:_Create_an_AWS_IAM_User) and [Step 2](https://aws.amazon.com/getting-started/tutorials/backup-to-s3-cli/#install-cli) of the ["Batch upload files to the cloud"](https://aws.amazon.com/getting-started/tutorials/backup-to-s3-cli/) 10-minute tutorial.

<table>
<tr><th>
:fire:  <span style="color: red;" >WARNING</span>
</th><td>
We <b>strongly</b> recommend following the
<a href='https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html'>IAM Security Best Practices</a> for securing your root AWS account and IAM users.
</td></tr>
</table>


<table>
<tr><th>
:pushpin:  <span style="color: blue;" >NOTE</span>
</th><td>
You can finish off the tutorial to get used to using the AWS CLI.
</td></tr>
</table>



### Step 0.3. Setting up a Amazon Virtual Private Cloud (VPC)

Amazon Virtual Private Cloud ([Amazon VPC](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Introduction.html)) enables you to launch AWS resources into a virtual network that you've defined. All users will need to designate a VPC to launch compute resources into.

While users are able to leverage a [default VPC and Subnets](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/default-vpc.html), we **strongly** recommend a more advanced setup that leverages private (not internet accessible) subnets and additional layers of security such as network Access Control Lists. There are [AWS Quickstart](https://aws.amazon.com/quickstart/) reference architectures for a [Modular and Scalable VPC Architecture](https://aws.amazon.com/quickstart/architecture/vpc/) serves this requirement.

:bulb:  <span style="color: ##FF6600;" >TIP</span>
<hr/>

You may also want to review the  [HIPAA on AWS Enterprise Accelerator](https://aws.amazon.com/quickstart/architecture/accelerator-hipaa/) for additional security best practices such as:

* Basic AWS Identity and Access Management (IAM) configuration with custom (IAM) policies, with associated groups, roles, and instance profiles
* Standard, external-facing Amazon Virtual Private Cloud (Amazon VPC) Multi-AZ architecture with separate subnets for different application tiers and private (back-end) subnets for application and database
* Amazon Simple Storage Service (Amazon S3) buckets for encrypted web content, logging, and backup data
* Standard Amazon VPC security groups for Amazon Elastic Compute Cloud (Amazon EC2) instances and load balancers used in the sample application stack
* A secured bastion login host to facilitate command-line Secure Shell (SSH) access to Amazon EC2 instances for troubleshooting and systems administration activities
* Logging, monitoring, and alerts using AWS CloudTrail, Amazon CloudWatch, and AWS Config rules
<hr/>

### Step 0.3. Setting up the AWS CLI

Once you have
## Step 1. Creating a custom AMI for genomics

Genomics, the main use case for Cromwell, is a data-heavy workload and requires some modification to the standard AWS Batch processing environment. In particular, we need to scale underlying instance storage that Tasks/Jobs run on top of to meet unpredictable runtime demands.

Specifically we will:

1. Launch and instance with a encrypted EBS volume
Follow steps **1 to 4** outlined in the AWS Batch documentation for [creating a compue resource AMI](https://docs.aws.amazon.com/batch/latest/userguide/create-batch-ami.html).

**Before step 5**, actually creating the new AMI, we will add a few more features to the build.

### Step 1.1. Adjusting the instance network

Containers that run on the instance can query for AWS credentials via the [instance metadata](). In order for that to happen, we adjust the

need to set the following networking commands on your container instance so that the containers in your tasks can retrieve their AWS credentials:

```shell
sudo sysctl -w net.ipv4.conf.all.route_localnet=1
sudo iptables -t nat -A PREROUTING -p tcp -d 169.254.170.2 --dport 80 -j DNAT --to-destination 127.0.0.1:51679
sudo iptables -t nat -A OUTPUT -d 169.254.170.2 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 51679
sudo service iptables save
```



###

## Step 2. Configuring AWS Batch

## Step 3. Configuring Cromwell
