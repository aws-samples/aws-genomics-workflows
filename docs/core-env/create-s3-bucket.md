# Data Storage

You will need a robust location to store your input and output data.  As mentioned
previously, genomics data files are fairly large.  In addition to input sample
files, genomics data processing typically relies on additional items like
reference sequences or annotation databases that can be equally large.

The following are key criteria for storing data for genomics workflows

* accessible to compute
* secure
* durable
* capable of handling large files

## Create an S3 Bucket

Amazon S3 buckets meet all of the above conditions.

You can use an existing bucket for your workflows, or you can create a new one using the CloudFormation template below.

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | :--: |
{{ cfn_stack_row("Amazon S3 Bucket", "GenomicsWorkflow-S3", "aws-genomics-s3.template.yaml", "Creates a secure Amazon S3 bucket to read from and write results to.") }}
