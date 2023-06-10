# Workflow Orchestration

{{ deprecation_notice() }}

Having deployed a way to execute individual tasks via AWS Batch, we turn to
orchestration of complete workflows.

In order to process data, we will need to handle the cases for serial and parallel task execution, and retry logic when a task fails.

The logic for workflows should live outside of the code for any individual task. There are a couple of options that researchers can use to define and execute repeatable data analysis pipelines on AWS Batch:

1. [AWS Step Functions](./step-functions/step-functions-overview.md), a native AWS service for workflow orchestration.

2. 3rd party alternatives:

    * [Cromwell](./cromwell/cromwell-overview.md), a workflow execution system
    from the [Broad Institute](https://www.broadinstitute.org/)

    * [Nextflow](./nextflow/nextflow-overview.md), a reactive workflow framework and domain specific language (DSL) from the [Comparative Bioinformatics group](https://www.crg.eu/en/programmes-groups/notredame-lab) at the Barcelona [Centre for Genomic Regulation (CRG)](http://www.crg.eu/)

!!! help
    There are many more 3rd party alternatives.  We are actively seeking out
    help to document them here!
