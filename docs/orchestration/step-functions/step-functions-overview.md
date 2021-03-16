# AWS Step Functions For Genomics Workflows

![AWS reference architecture for genomics](./images/aws-sfn-genomics-workflow-arch.png)

The [AWS Step Functions](https://aws.amazon.com/step-functions/) service allows you to orchestrate other AWS services, such as Lambda, Batch, SNS, and Glue, making it easy to coordinate the components of distributed applications as a series of steps in a visual workflow.

In the context of genomics workflows, the combination of AWS Step Functions with Batch and Lambda constitutes a robust, scalable, and serverless task orchestration solution.

## Requirements

To get started using AWS Step Functions for genomics workflows you'll need the following setup in your AWS account:

* A VPC with at least 2 subnets (preferrably ones that are **private**)
* The Genomics Workflow [Core Environment](../../core-env/introduction.md)
* Containerized tools for your workflow steps like BWA-MEM, Samtools, BCFtools custom entrypoint scripts that uses AWS Batch supplied environment variables for configuration and data handling
* A Batch Job Definitions for your tools
* An IAM Role for AWS Step Functions that allows it to submit AWS Batch jobs


The following will help you deploy these components

### VPC

If you are handling sensitive data in your genomics pipelines, we recommend using at least 2 **private** subnets for AWS Batch compute jobs. EC2 instances launched into **private** subnets do not have public IP addresses, and therefore cannot be directly accessed from the public internet. They can still retain internet access from within the VPC - e.g. to pull source code, retrive public datasets, or install required softwre - if networking is configured appropriately. If the target VPC you want to deploy into already has this, you can skip ahead. If not, you can use the CloudFormation template below, which uses the [AWS VPC Quickstart](https://aws.amazon.com/quickstart/architecture/vpc/), to create one meeting these requirements.

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | :--: |
{{ cfn_stack_row("VPC (Optional)", "GenomicsVPC", "https://aws-quickstart.s3.amazonaws.com/quickstart-aws-vpc/templates/aws-vpc.template.yaml", "Creates a new Virtual Private Cloud to use for your genomics workflow resources.") }}

### Genomics Workflow Core

To launch the Genomics Workflow Core in your AWS account, use the CloudFormation template below.

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | :--: |
{{ cfn_stack_row("Genomics Workflow Core", "gwfcore", "gwfcore/gwfcore-root.template.yaml", "Create EC2 Launch Templates, AWS Batch Job Queues and Compute Environments, a secure Amazon S3 bucket, and IAM policies and roles within an **existing** VPC. _NOTE: You must provide VPC ID, and subnet IDs_.") }}

The core is agnostic of the workflow orchestrator you intended to use, and can be installed multiple times in your account if needed (e.g. for use by different projects). Each installation uses a `Namespace` value to group resources accordingly. By default, the `Namespace` is set to the stack name, which must be unique within an AWS region.

See the [Core Environment](../../core-env/introduction.md) For more details on the core's architecture.

### Step Functions Resources

The the following CloudFormation template will create an AWS Step Functions State Machine that defines an example variant calling workflow using BWA-MEM, Samtools, and BCFtools; container images and AWS Batch Job Definitions for the tooling; and an IAM Role that allows AWS Step Functions to call AWS Batch during State Machine executions:

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | -- |
{{ cfn_stack_row("AWS Step Functions Resources", "sfn-resources", "step-functions/sfn-resources.template.yaml", "Create a Step Functions State Machine, Batch Job Definitions, and container images to run an example genomics workflow") }}

## Deployment Details

### AWS Step Functions Execution Role

An AWS Step Functions Execution role is an IAM role that allows Step Functions to execute other AWS services via the state machine.

This can be created automatically during the "first-run" experience in the AWS Step Functions console when you create your first state machine.  The policy attached to the role will depend on the specifc tasks you incorporate into your state machine.

State machines that use AWS Batch for job execution and send events to CloudWatch should have an Execution role with the following inline policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "enable submitting batch jobs",
            "Effect": "Allow",
            "Action": [
                "batch:SubmitJob",
                "batch:DescribeJobs",
                "batch:TerminateJob"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "events:PutTargets",
                "events:PutRule",
                "events:DescribeRule"
            ],
            "Resource": [
                "arn:aws:events:<region>:<account-number>:rule/StepFunctionsGetEventsForBatchJobsRule"
            ]
        }
    ]
}
```

For more complex workflows that use nested workflows or require more complex input parsing, you need to add additional permissions for executing Step Functions State Machines and invoking Lambda functions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "enable calling lambda functions",
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": "*"
        },
        {
            "Sid": "enable calling other step functions",
            "Effect": "Allow",
            "Action": [
                "states:StartExecution"
            ],
            "Resource": "*"
        },
        ...
    ]
}
```

!!! note
    All `Resource` values in the policy statements above can be scoped to be more specific if needed.

### Step Functions State Machines

Workflows in AWS Step Functions are built using [Amazon States Language](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-amazon-states-language.html) (ASL), a declarative, JSON-based, structured language used to define a "state-machine".  An AWS Step Functions State-Machine is a collection of states that can do work (Task states), determine which states to transition to next (Choice states), stop an execution with an error (Fail states), and so on.

#### Building workflows with AWS Step Functions

The overall structure of a state-machine looks like the following:

```json
{
  "Comment": "Description of you state-machine",
  "StartAt": "FirstState",
  "States": {
    "FirstState": {
        "Type": "<state-type>",
        "Next": "<name of next state>"
    },

    "State1" : {
        ...
    },
    ...

    "StateN" : {
        ...
    },

    "LastState": {
        ...
        "End": true
    }
  }
}
```

A simple "Hello World" state-machine looks like this:

```json
{
  "Comment": "A Hello World example of the Amazon States Language using a Pass state",
  "StartAt": "HelloWorld",
  "States": {
    "HelloWorld": {
      "Type": "Pass",
      "Result": "Hello World!",
      "End": true
  }
}
```

ASL supports several task types and simple structures that can be combined to form a wide variety of complex workflows.

![ASL Structures](images/step-functions-structures.png)

More detailed coverage of ASL state types and structures is provided in the 
Step Functions [ASL documentation](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-amazon-states-language.html).

#### Batch Job Definitions

[AWS Batch Job Definitions](https://docs.aws.amazon.com/batch/latest/userguide/job_definitions.html) are used to define compute resource requirements and parameter defaults for an AWS Batch Job.  These are then referenced in state machine `Task` states by their respective ARNs.

An example Job Definition for the `bwa-mem` sequence aligner is shown below:

```json
{
    "jobDefinitionName": "bwa-mem",
    "type": "container",
    "parameters": {
        "threads": "8"
    },
    "containerProperties": {
        "image": "<dockerhub-user>/bwa-mem:latest",
        "vcpus": 8,
        "memory": 32000,
        "command": [
            "bwa", "mem",
            "-t", "Ref::threads",
            "-p",
            "reference.fasta",
            "sample_1.fastq.gz"
        ],
        "volumes": [
            {
                "host": {
                    "sourcePath": "/scratch"
                },
                "name": "scratch"
            },
            {
                "host": {
                    "sourcePath": "/opt/miniconda"
                },
                "name": "aws-cli"
            }
        ],
        "environment": [
            {
                "name": "REFERENCE_URI",
                "value": "s3://<bucket-name>/reference/*"
            },
            {
                "name": "INPUT_DATA_URI",
                "value": "s3://<bucket-name>/<sample-name>/fastq/*.fastq.gz"
            },
            {
                "name": "OUTPUT_DATA_URI",
                "value": "s3://<bucket-name>/<sample-name>/aligned"
            }
        ],
        "mountPoints": [
            {
                "containerPath": "/opt/work",
                "sourceVolume": "scratch"
            },
            {
                "containerPath": "/opt/miniconda",
                "sourceVolume": "aws-cli"
            }
        ],
        "ulimits": []
    }
}
```

There are three key parts of the above definition to take note of.

* Command and Parameters

    The **command** is a list of strings that will be sent to the container.  This is the same as the `...` arguments that you would provide to a `docker run mycontainer ...` command.

    **Parameters** are placeholders that you define whose values are substituted when a job is submitted.  In the case above a `threads` parameter is defined with a default value of `8`.  The job definition's `command` references this parameter with `Ref::threads`.

    !!! note
        Parameter references in the command list must be separate strings - concatenation with other parameter references or static values is not allowed.

* Environment

    **Environment** defines a set of environment variables that will be available for the container. For example, you can define environment variables used by the container entrypoint script to identify data it needs to stage in.

* Volumes and Mount Points

    Together, **volumes** and **mountPoints** define what you would provide as using a `-v hostpath:containerpath` option to a `docker run` command.  These can be used to map host directories with resources (e.g. data or tools) used by all containers.  In the example above, a `scratch` volume is mapped so that the container can utilize a larger disk on the host.  Also, a version of the AWS CLI installed with `conda` is mapped into the container - enabling the container to have access to it (e.g. so it can transfer data from S3 and back) with out explicitly building in.


#### State Machine Batch Job Tasks

AWS Step Functions has built-in integration with AWS Batch (and [several other services](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-connectors.html)), and provides snippets of code to make developing your state-machine tasks easier.

![Manage a Batch Job Snippet](images/sfn-batch-job-snippet.png)

The corresponding state machine state for the `bwa-mem` Job definition above
would look like the following:

```json
"BwaMemTask": {
    "Type": "Task",
    "InputPath": "$",
    "ResultPath": "$.bwa-mem.status",
    "Resource": "arn:aws:states:::batch:submitJob.sync",
    "Parameters": {
        "JobDefinition": "arn:aws:batch:<region>:<account>:job-definition/bwa-mem:1",
        "JobName": "bwa-mem",
        "JobQueue": "<queue-arn>",
        "Parameters.$": "$.bwa-mem.parameters",
        "Environment": [
            {"Name": "REFERENCE_URI",
             "Value.$": "$.bwa-mem.environment.REFERENCE_URI"},
            {"Name": "INPUT_DATA_URI",
             "Value.$": "$.bwa-mem.environment.INPUT_DATA_URI"},
            {"Name": "OUTPUT_DATA_URI",
             "Value.$": "$.bwa-mem.environment.OUTPUT_DATA_URI"}
        ]
    },
    "Next": "NEXT_TASK_NAME"
}
```

Inputs to a state machine that uses the above `BwaMemTask` would look like this:

```json
{
    "bwa-mem": {
        "parameters": {
            "threads": 8
        },
        "environment": {
            "REFERENCE_URI": "s3://<bucket-name/><sample-name>/reference/*",
            "INPUT_DATA_URI": "s3://<bucket-name/><sample-name>/fastq/*.fastq.gz",
            "OUTPUT_DATA_URI": "s3://<bucket-name/><sample-name>/aligned"
        }
    },
    ...
}
```

When the Task state completes Step Functions will add information to a new `status` key under `bwa-mem` in the JSON object.  The complete object will be passed on to the next state in the workflow.

### Example state machine

The example workflow is a simple secondary analysis pipeline that converts raw FASTQ files into VCFs with variants called for a list of chromosomes.  It uses the following open source based tools:

* `bwa-mem`: Burrows-Wheeler Aligner for aligning short sequence reads to a reference genome
* `samtools`: **S**equence **A**lignment **M**apping library for indexing and sorting aligned reads
* `bcftools`: **B**inary (V)ariant **C**all **F**ormat library for determining variants in sample reads relative to a reference genome

Read alignment, sorting, and indexing occur sequentially by Step Functions Task States.  Variant calls for chromosomes occur in parallel using a Step Functions Map State and sub-Task States therein.  All tasks submit AWS Batch Jobs to perform computational work using containerized versions of the tools listed above.

![example genomics workflow state machine](./images/sfn-example-mapping-state-machine.png)

The tooling containers used by the workflow use a [generic entrypoint script]({{ repo_url + "tree/master/src/containers" }}) that wraps the underlying tool and handles S3 data staging.  It uses the AWS CLI to transfer objects and environment variables to identify data inputs and outputs to stage.

### Running the workflow

When the stack above completes, go to the outputs tab and copy the JSON string provided in `StateMachineInput`.

![cloud formation output tab](./images/cfn-stack-outputs-tab.png)
![example state-machine input](./images/cfn-stack-outputs-statemachineinput.png)

The input JSON will look like the following, but with the values for `queue` and `JOB_OUTPUT_PREFIX` prepopulated with resource names specific to the stack created by the CloudFormation template above:

```json
{
    "params": {
        "__comment__": {
            "replace values for `queue` and `environment.JOB_OUTPUT_PREFIX` with values that match your resources": {
                "queue": "Name or ARN of the AWS Batch Job Queue the workflow will use by default.",
                "environment.JOB_OUTPUT_PREFIX": "S3 URI (e.g. s3://bucket/prefix) you are using for workflow inputs and outputs."
            },
        },
        "queue": "default",
        "environment": {
            "REFERENCE_NAME": "Homo_sapiens_assembly38",
            "SAMPLE_ID": "NIST7035",
            "SOURCE_DATA_PREFIX": "s3://aws-batch-genomics-shared/secondary-analysis/example-files/fastq",
            "JOB_OUTPUT_PREFIX": "s3://YOUR-BUCKET-NAME/PREFIX",
            "JOB_AWS_CLI_PATH": "/opt/miniconda/bin"
        },
        "chromosomes": [
            "chr19",
            "chr20",
            "chr21",
            "chr22"
        ]
    }
}
```

Next head to the AWS Step Functions console and select the state-machine that was created.

![select state-machine](./images/sfn-console-statemachine.png)

Click the "Start Execution" button.

![start execution](./images/sfn-console-start-execution.png)

In the dialog that appears, paste the input JSON into the "Input" field, and click the "Start Execution" button.  (A unique execution ID will be automatically generated).

![start execution dialog](./images/sfn-console-start-execution-dialog.png)

You will be taken to the execution tracking page where you can monitor the progress of your workflow.

![execution tracking](./images/sfn-console-execution-inprogress.png)

The example workflow references a small demo dataset and takes approximately 20-30 minutes to complete.

## Cost optimizing workflows
[Optimizing](../cost-effective-workflows/cost-effective-workflows.md) the allocation of resources to your workflows can help you to reduce costs