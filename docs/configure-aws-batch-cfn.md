# Configure AWS Batch for genomics workflows

## TL;DR

The links below provide a fully configured AWS environment for setting up AWS Batch for genomics workflows. In all cases, you will need the AMI ID for the AWS Batch Compute Resource AMI that you created using the ["Create a Custom AMI"](./create-custom-ami) guide.

https://aws-quickstart.s3.amazonaws.com/quickstart-aws-vpc/templates/aws-vpc.template

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | -- |
| Full Stack   | Launch a full AWS environment, including a new VPC, IAM policies and roles, Amazon S3 buckets for data and logging, and AWS Batch Job Queue and Compute Environments. _You must provide the custome AMI ID_.|  [:fa-eye:](https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-fullstack.yaml) | [![cloudformation-launch-button](./images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=Cromwell-VPC-IAM-Batch-S3&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-fullstack.yaml) |
| Existing VPC | Create AWS Batch Job Queues and Compute Environments, a secure Amazon S3 bucket, and IAM policies and roles within an existing VPC. _You must provide custom AMI ID, VPC ID, and subnet IDs_. |  [:fa-eye:](https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-halfstack.yaml) | [![cloudformation-launch-button](./images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=Cromwell-IAM-Batch-S3&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-halfstack.yaml) |

The individual components from above are available as stand-alone CloudFormation templates as well, in case you need to have elevated privileges to execute them. You will need to provide some output values from one template to the others.


| Name | Description | Source | Launch Stack |
| -- | -- | :--: | -- |
| Amazon VPC | The AWS reference VPC deployment from the **[Modular and Scalable VPC Architecure](https://aws.amazon.com/quickstart/architecture/vpc/)** guide. Great for deploying genomics workflows to. |  [:fa-eye:](https://aws-quickstart.s3.amazonaws.com/quickstart-aws-vpc/templates/aws-vpc.template) | [![cloudformation-launch-button](./images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=Cromwell-VPC&templateURL=https://aws-quickstart.s3.amazonaws.com/quickstart-aws-vpc/templates/aws-vpc.template) |
| Amazon S3 | Creates a secure Amazon S3 bucket to read from and write results to. |   [:fa-eye:](https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-s3.yaml) | [![cloudformation-launch-button](./images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=Cromwell-S3&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-s3.yaml) |
| Amazon IAM   | Create the necessary IAM Roles. This is useful to hand to someone with the right permissions to create these on your behalf. _You will need to provide a S3 bucket name_. |  [:fa-eye:](https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-iam.yaml) | [![cloudformation-launch-button](./images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=Cromwell-IAM&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-iam.yaml) |
| AWS Batch | Creates AWS Batch Job Queues and Compute Environments. You will need to provide the details on IAM roles and instance profiles, and the IDs for a VPC and subnets. |  [:fa-eye:](https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-fullstack.yaml) | [![cloudformation-launch-button](./images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=Cromwell-Batch&templateURL=https://s3.amazonaws.com/cromwell-aws-batch/templates/cromwell-fullstack.yaml) |

## Look at what you just did!
