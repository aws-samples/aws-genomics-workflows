# Deploy the reference architecture for Cromwell

## TL;DR

The links below provide a fully configured AWS environment for running Cromwell within your AWS account. It sets up:

1. A Amazon VPC

| AWS Region | Short name | &nbsp; |
| -- | -- | -- |
| US East (N. Virginia) | us-east-1 | [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| US East (Ohio) | us-east-2 | [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| US West (Oregon) | us-west-1 | [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=us-west-1#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| US West (N. California) | us-west-2 | [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=us-west-2#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| Canada (Central) | ca-central-1 | [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=ca-central-1#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| EU (Ireland) | eu-west-1 | [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| EU (London) | eu-west-2 | [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=eu-west-2#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| EU (Paris) | eu-west-3 | [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=eu-west-3#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| EU (Frankfurt) | eu-central-1 | [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=eu-central-1#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| Asia Pacific (Tokyo) | ap-northeast-1 | [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=ap-northeast-1#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| Asia Pacific (Seoul) | ap-northeast-2 | [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=ap-northeast-2#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| Asia Pacific (Singapore) | ap-southeast-1 | [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=ap-southeast-1#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| Asia Pacific (Sydney) | ap-southeast-2 | [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=ap-southeast-2#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| Asia Pacific (Mumbai) | ap-south-1 |  [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=ap-south-1#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |
| South America (São Paulo) | sa-east-1 |  [![cloudformation-launch-button](images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=sa-east-1#/stacks/new?stackName=Production&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-root.yaml) |

# Notes on AWS Batch for Cromwell

Once we have all of the above, we can configure and quickly test AWS Batch for use with Cromwell.

Many of the basic steps are covered in the [AWS Batch documentation](https://docs.aws.amazon.com/batch/latest/userguide/get-set-up-for-aws-batch.html) but we have provided a CloudFormation template to create the following resources within, and for use with, AWS Batch:

1. IAM Roles for use with AWS services such as S3, EC2, ECS and Spot Fleet.
2. AWS Batch `Compute Environment`s for on-demand and Spot EC2 instances.
3. AWS Batch `Job Queue`s for high and regular priority `Job`s
