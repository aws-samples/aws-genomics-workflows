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

Follow the directions in the ["Creating a custom AMI for genomics"](./doc/create-custom-ami.md) guide.

## [Step 2.](id:step-2) Launch and configure an AWS reference architecture for use with Cromwell

Once you have a custom AMI ID, such as `ami-a7a242da`, you  can launch the reference architecture CloudFormation stack in your account, using one of the links below. A full description of what is going on is described in the ["Deploying AWS Batch"](./doc/cofigure-aws-batch-start.md) guide.

![AWS Batch environment for genomics](https://d2908q01vomqb2.cloudfront.net/1b6453892473a467d07372d45eb05abc2031647a/2018/04/23/Picture2.png)

## [Step 3.](id:step-3) Configuring Cromwell for AWS

Once you have a suitable AWS Batch environment for genomics workflows, you can leverage it with other systems, such as AWS Step Functions, [Cromwell](LINK), and  [Nextflow.io](https://nextflow.io).

* **[Configure AWS Lambda and AWS Step Functions](./docs/configure-aws-native.md)**
* **[Configure Cromwell](./docs/configure-cromwell-aws-batch.md)**
<!-- * **[Configure Nextflow.io](./configure-nextflow-aws-batch.md)** -->

 