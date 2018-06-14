# Genomics Workflows

Now that we have a way to execute individual tasks via AWS Batch, we turn to orchastration of complete workflows. A typical genomics workflow is represented by the diagram below:

![Typical genomics workflow](./images/genomics-workflow.png)

In order to process data, we will need to handle the cases for serial and parallel task execution, and retry logic when a task fails.

The domain logic for workflows should live outside of the code for any individual task. There are a couple of systems that researchers can use to define and execute repeatable data analysis pipelines on AWS Batch:

1. [Native AWS services](./configure-step-functions-aws-batch.md) such as AWS Lambda and AWS Step Functions.
2. [Cromwell](./configure-cromwell-aws-batch.md), a workflow management system from the Broad Institute
3. [Nextflow](./configure-nextflow-aws-batch.md), another workflow management system well used by the bioinformatics community.

Follow one of the links above to configure a full genomics workflows computing environment on AWS.

!!! note
    We do not cover other systems such as Galaxy or SnakeMake as they do not support AWS Batch (yet).
