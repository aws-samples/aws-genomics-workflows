# Core: Data Storage

You will need a robust location to store your input and output data.  Genomics data files often equal or exceed 100GB per file.  In addition to input sample files, genomics data processing typically relies on additional items like reference sequences or annotation databases that can be equally large.

The following are key criteria for storing data for genomics workflows

* accessible to compute
* secure
* durable
* capable of handling large files

Amazon S3 buckets meet all of the above conditions.  S3 also makes it easy to collaboratively work on such large datasets because buckets and the data stored in them are globally available.

You can use an S3 bucket to store both your input data and workflow results.

## Create an S3 Bucket

You can use an existing bucket for your workflows, or you can create a new one using the methods below.

### Automated via Cloudformation

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | :--: |
{{ cfn_stack_row("Amazon S3 Bucket", "GWFCore-S3", "gwfcore/gwfcore-s3.template.yaml", "Creates a secure Amazon S3 bucket to read from and write results to.", enable_cfn_button=False) }}

!!! info
    The launch button has been disabled above since this template is part of a set of nested templates. It is not recommended to launch it independently of its intended parent stack.

### Manually via the AWS Console

* Go to the S3 Console
* Click on the "Create Bucket" button

In the dialog that opens:

* Provide a "Bucket Name".  This needs to be globally unique.

* Select the region for the bucket.  Buckets are globally accessible, but the data resides on physical hardware within a specific region.  It is best to choose a region that is closest to where you are and where you will launch compute resources to reduce network latency and avoid inter-region transfer costs.

The default options for bucket configuration are sufficient for the marjority of use cases.

* Click the "Create" button to accept defaults and create the bucket.
