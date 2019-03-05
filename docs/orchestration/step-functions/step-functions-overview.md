# AWS Step Functions For Genomics Workflows

![AWS reference architecture for genomics](./images/aws-sfn-genomics-workflow-arch.png)

[AWS Step Functions](https://aws.amazon.com/step-functions/) is a service that allows you to orchestrate other AWS services, such as Lambda, Batch, SNS, and Glue, making it easy to coordinate the components of distributed applications as a series of steps in a visual workflow.

In the context of genomics workflows, the combination of AWS Step Functions with Batch and Lambda constitutes a robust, scalable, and serverless task orchestration solution.

## TL;DR

If you need something up and running in a hurry, a fully automated setup process
is provided at this GitHub repository:

[AWS Batch Genomics](https://github.com/aws-samples/aws-batch-genomics)

If you are interested in creating your own solution with AWS Step Functions and AWS Batch,
read through the rest of this page.

## Prerequisites

To get started using AWS Step Functions for genomics workflows you'll need the following setup in your AWS account:

* The core set of resources (S3 Bucket, IAM Roles, AWS Batch) described in the [Getting Started](../../../core-env/introduction/) section.

## AWS Step Functions Execution Role

An AWS Step Functions Execution role is an IAM role that allows Step Functions to execute other AWS services via the state machine.

This can be created automatically during the "first-run" experience in the AWS Step Functions console when you create your first state machine.  The policy attached to the role will depend on the specifc tasks you incorporate into your state machine.

State machines that use AWS Batch for job execution and send events to CloudWatch should have an Execution role with the following inline policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
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

## Step Functions State Machine

Workflows in AWS Step Functions are built using [Amazon States Language](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-amazon-states-language.html) (ASL), a declarative, JSON-based, structured language used to define your state machine, a collection of states that can do work (Task states), determine which states to transition to next (Choice states), stop an execution with an error (Fail states), and so on.

### Building workflows with AWS Step Functions

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

### Batch Job Definitions

It is recommended to have [Batch Job Definitions](https://docs.aws.amazon.com/batch/latest/userguide/job_definitions.html) created for your tooling prior to building a Step Functions state machine.  These can then be referenced in state machine `Task` states by their respective ARNs.

Step Functions will use the Batch Job Definition to define compute resource requirements and parameter defaults for the Batch Job it submits.

An example Job Definition for the `bwa-mem` sequence aligner is shown below:

```json
{
    "jobDefinitionName": "bwa-mem",
    "type": "container",
    "parameters": {
        "InputReferenceS3Prefix": "s3://<bucket-name>/reference",
        "InputFastqS3Path1": "s3://<bucket-name>/<sample-name>/fastq/read1.fastq.gz",
        "InputFastqS3Path2": "s3://<bucket-name>/<sample-name>/fastq/read2.fastq.gz",
        "OutputS3Prefix": "s3://<bucket-name>/<sample-name>/aligned"
    },
    "containerProperties": {
        "image": "<dockerhub-user>/bwa-mem:latest",
        "vcpus": 8,
        "memory": 32000,
        "command": [
            "Ref::InputReferenceS3Prefix",
            "Ref::InputFastqS3Path1",
            "Ref::InputFastqS3Path2",
            "Ref::OutputS3Prefix",
        ],
        "volumes": [
            {
                "host": {
                    "sourcePath": "/scratch"
                },
                "name": "scratch"
            }
        ],
        "environment": [],
        "mountPoints": [
            {
                "containerPath": "/opt/work",
                "sourceVolume": "scratch"
            }
        ],
        "ulimits": []
    }
}
```

!!! note
    The Job Definition above assumes that `bwa-mem` has been containerized with an
    `entrypoint` script that handles Amazon S3 URIs for input and output data
    staging.

    Because data staging requirements can be unique to the tooling used, neither AWS Batch nor Step Functions handles this automatically.

!!! note
    The `volumes` and `mountPoints` specifications allow the job container to
    use scratch storage space on the instance it is placed on.  This is equivalent
    to the `-v host_path:container_path` option provided to a `docker run` call
    at the command line.

### State Machine Batch Job Tasks

Conveniently for genomics workflows, AWS Step Functions has built-in integration with AWS Batch (and [several other services](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-connectors.html)), and provides snippets of code to make developing your state-machine
Batch tasks easier.

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
        "Parameters.$": "$.bwa-mem.parameters"
    },
    "Next": "NEXT_TASK_NAME"
}
```

Inputs to a state machine that uses the above `BwaMemTask` would look like this:

```json
{
    "bwa-mem": {
        "parameters": {
            "InputReferenceS3Prefix": "s3://<bucket-name/><sample-name>/reference",
            "InputFastqS3Path1": "s3://<bucket-name/><sample-name>/fastq/read1.fastq.gz",
            "InputFastqS3Path2": "s3://<bucket-name/><sample-name>/fastq/read2.fastq.gz",
            "OutputS3Prefix": "s3://<bucket-name/><sample-name>/aligned"
        }
    },
    ...
 }
```

When the Task state completes Step Functions will add information to a new `status` key under `bwa-mem` in the JSON object.  The complete object will be passed on to the next state in the workflow.
