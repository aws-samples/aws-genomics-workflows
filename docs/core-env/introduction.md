# Core: Introduction

A high level view of the architecture you will need to run workflows is shown is below.

![high level architecture](images/aws-genomics-workflows-high-level-arch.png)

This section of the guide details the common components required for job execution and data storage. This includes the following:

* A place to store your input data and generated results
* Access controls to your data and compute resources
* Code and artifacts used to provision compute resources
* Containerized task scheduling and execution

The above is referred to here as the "Genomics Workflows Core". To launch this core in your AWS account, use the Cloudformation template below.

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | :--: |
{{ cfn_stack_row("Genomics Workflow Core", "gwfcore", "gwfcore/gwfcore-root.template.yaml", "Create EC2 Launch Templates, AWS Batch Job Queues and Compute Environments, a secure Amazon S3 bucket, and IAM policies and roles within an **existing** VPC. _NOTE: You must provide VPC ID, and subnet IDs_.") }}

The core is agnostic of the workflow orchestrator you intended to use, and can be installed multiple times in your account if needed (e.g. for use by different projects). Each installation uses a `Namespace` value to group resources accordingly. By default, the `Namespace` is set to the stack name, which must be unique within an AWS region.

!!! info
    To create all of the resources described, the Cloudformation template above uses [Nested Stacks](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-nested-stacks.html). This is a way to modularize complex stacks and enable reuse. The individual nested stack templates are intended to be run from a parent or "root" template. On the following pages, the individual nested stack templates are available for viewing only.
