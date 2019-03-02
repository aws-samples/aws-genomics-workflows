# Workflow Orchestration

Now that we have a way to execute individual tasks via AWS Batch, we turn to
orchestration of complete workflows.

In order to process data, we will need to handle the cases for serial and parallel task execution, and retry logic when a task fails.

The logic for workflows should live outside of the code for any individual task. There are a couple of systems that researchers can use to define and execute repeatable data analysis pipelines on AWS Batch:

1. [AWS Step Functions](./step-functions/intro-step-functions.md), a native AWS service for workflow orchestration.

2. [Cromwell](./cromwell/cromwell-aws-batch.md), a workflow management system from the [Broad Institute](https://www.broadinstitute.org/)

<!-- 3. [Nextflow](./nextflow/nextflow-aws-batch.md), another workflow management system well used by the bioinformatics community. -->

Follow one of the links above to configure a full genomics workflows computing environment on AWS.
