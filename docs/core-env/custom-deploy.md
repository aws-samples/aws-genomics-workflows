# Customized Templates and Artifacts

Deployments of the 'Nextflow on AWS Batch' solution are based on nested CloudFormation templates, and on artifacts comprising scripts, software packages, and configuration files.  The templates and artifacts are stored in S3 buckets, and their S3 URLs are used when launching the top-level template and as parameters to that template's deployment.  

## VPC
The quick start link deploys the [AWS VPC Quickstart](https://aws.amazon.com/quickstart/architecture/vpc/), which creates a VPC with up to 4 Availability Zones, each with a public subnet and a private subnet with NAT Gateway access to the Internet.

## Genomics Workflow Core
This quick start link deploys the CloudFormation template `gwfcore-root.template.yaml` for the Genomics Workflow Core (GWFCore) from the [Genomics Workflows on AWS](https://github.com/aws-samples/aws-genomics-workflows) solution.  This template launches a number of nested templates, as shown below:

* Root Stack __gwfcore-root__ - Top level template for Genomics Workflow Core
    * S3 Stack __gwfcore-s3__ - S3 bucket (new or existing) for storing analysis results
    * IAM Stack __gwfcore-iam__ - Creates IAM roles to use with AWS Batch scalable genomics workflow environment
    * Code Stack __gwfcore-code__ - Creates AWS CodeCommit repos and CodeBuild projects for Genomics Workflows Core assets and artifacts
    * Launch Template Stack __gwfcore-launch-template__ - Creates an EC2 Launch Template for AWS Batch based genomics workflows
    * Batch Stack __gwfcore-batch__ - Deploys resource for a AWS Batch environment that is suitable for genomics, including default and high-priority JobQueues

### Root Stack
The quick start solution links to the CloudFormation console, where the 'Amazon S3 URL' field is prefilled with the S3 URL of a copy of the root stack template, hosted in the public S3 bucket __aws-genomics-workflows__.

<img src="https://dpkk088kye7gn.cloudfront.net/aws-genomics-workflows/docs/images/custom-deploy-0.png"
     alt="custom-deploy-0"
     width="100%" height="100%"
     class="screenshot" />

To use a customized root stack, upload your modified stack template to an S3 bucket (see [Building a Custom Distribution](build-custom-distribution.md)), and specify that template's URL in 'Amazon S3 URL'.

### Artifacts and Nested Stacks
The subsequent screen, 'Specify Stack Details', allows for customization of the deployed resources in the 'Distribution Configuration' section.

<img src="https://dpkk088kye7gn.cloudfront.net/aws-genomics-workflows/docs/images/custom-deploy-1.png"
     alt="custom-deploy-1"
     width="70%" height="70%"
     class="screenshot" />

* __Artifact S3 Bucket Name__ and __Artifact S3 Prefix__ define the location of the artifacts uploaded prior to this deployment.  By default, pre-prepared artifacts are stored in the __aws-genomics-workflows__ bucket.  
* __Template Root URL__ defines the bucket and prefix used to store nested templates, called by the root template.  

To use your own modified artifacts or nested templates, build and upload as described in [Building a Custom Distribution](build-custom-distribution.md), and specify the  bucket and prefix in the fields above.

## Workflow Orchestrators
### Nextflow
This quick start deploys the Nextflow template `nextflow-resources.template.yaml`, which launches one nested stack:

* Root Stack __nextflow-resources__ - Creates resources specific to running Nextflow on AWS
    * Container Build Stack __container-build__ - Creates resources for building a Docker container image using CodeBuild, storing the image in ECR, and optionally creating a corresponding Batch Job Definition

The nextflow root stack is specified in the same way as the GWFCore root stack, above, and a location for a modified root stack may be specified as with the Core stack.

The subsequent 'Specify Stack Details' screen has fields allowing the customization of the Nextflow deployment.

<img src="https://dpkk088kye7gn.cloudfront.net/aws-genomics-workflows/docs/images/nextflow-0.png"
     alt="nextflow-0"
     width="70%" height="70%"
     class="screenshot" />

* __S3NextflowPrefix__, __S3LogsDirPrefix__, and __S3WorkDirPrefix__ specify the path within the GWFCore bucket in which to store per-run data and log files.
* __TemplateRootUrl__ specifies the path to the nested templates called by the Nextflow root template, as with the GWFCore root stack.
