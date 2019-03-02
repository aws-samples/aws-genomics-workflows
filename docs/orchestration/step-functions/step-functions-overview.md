# AWS Step Functions For Genomics Workflows

A system for defining and executing genomics workflows can be subdivided into three main service areas.

1. Services for managing applications and data.
2. Serivces for individual task execution.
3. Orchastration services that manage the execution of processes and the flow of data between tasks.

The following diagram illustrates a reference AWS architecture for these three service layers.

![AWS reference architecture for genomics](images/aws-genomics-ref-arch.png)

For **data**, we leverage Amazon S3 as the source of truth. All input and output data are staged to/from S3 as part of the task. **Applications** are deployed as Docker containers, and Amazon Elastic Container Registry is used to hold our Docker container images.

For **task scheduling and execution**, we rely on AWS Batch.

For **orchastration between tasks**, [AWS Step Functions](https://aws.amazon.com/step-functions/) to orchastrate complex workflows by interacting directly with AWS Batch.

In the next sections, we will cover an example of how to impement a workflow system that leverages AWS Step Functions.