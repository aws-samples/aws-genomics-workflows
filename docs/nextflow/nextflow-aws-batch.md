# Nextflow.io on AWS Batch

Configuring Nextflow to leverage AWS Batch only requires two items:

1. That **either** the pipeline processes **or** the `nextflow.config` file define the `container` directive
2. That the `process.executor` property is set to `'awsbatch'` in the `nextflow.config` file

Here is an example config file that has two

```json

```

## Pre-configured EC2 instance

The following CloudFormation template will launch a EC2 instance pre-configured for using Nextflow.

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | -- |
| Login Host Nextflow | Launch a EC2 instance preconfigured for Nextflow and AWS Batch. |  [:fa-eye:](https://raw.githubusercontent.com/aws-samples/aws-batch-genomics/master/src/templates/login-host-nextflow.yaml) | [![cloudformation-launch-button](./images/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=LoginHost-Nextflow&templateURL=https://raw.githubusercontent.com/aws-samples/aws-batch-genomics/master/src/templates/login-host-nextflow.yaml) |
