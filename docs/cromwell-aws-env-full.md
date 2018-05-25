# Deploy the reference architecture for Cromwell

## TL;DR

The links below provide a fully configured AWS environment for running Cromwell within your AWS account. A full environment consists of:

1. An Amazon VPC with public and private subnets.
2. An AWS Batch environment.
3. A EC2 host preconfigured for Cromwell on AWS


https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=Cromwell&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml

| Name | Description | &nbsp; |
| :-- | :-- | :-- |
| Full template | A complete environment including VPC, AWS Batch, and a login host preconfigured with Cromwell | [![cloudformation-launch-button](cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=Cromwell&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-vpc-batch-host.yaml) |
| Existing VPC | Configure AWS Batch and launch a login host preconfigured with Cromwell | [![cloudformation-launch-button](cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=Cromwell&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-batch-host.yaml) |
| Login Host Only | Assuming you have a AWS Batch Job Queue, launch a login host preconfigured with Cromwell | [![cloudformation-launch-button](cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=Cromwell&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-host.yaml) |

# Overview



# Notes on AWS Batch for Cromwell

Once we have all of the above, we can configure and quickly test AWS Batch for use with Cromwell.

Many of the basic steps are covered in the [AWS Batch documentation](https://docs.aws.amazon.com/batch/latest/userguide/get-set-up-for-aws-batch.html) but we have provided a CloudFormation template to create the following resources within, and for use with, AWS Batch:

1. IAM Roles for use with AWS services such as S3, EC2, ECS and Spot Fleet.
2. AWS Batch `Compute Environment`s for on-demand and Spot EC2 instances.
3. AWS Batch `Job Queue`s for high and regular priority `Job`s
