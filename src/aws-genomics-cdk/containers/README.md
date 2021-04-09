# Setting up bioinformatics containers

The CDK genomics pipeline project is leveraging 
[AWS Batch](https://aws.amazon.com/batch/) for 
running bioinformatics jobs. AWS Batch works with docker containers which means 
we'll need to build or use an existing docker container with the bioinfomatics 
tools installed.

Start by creating a folder for your tool and place the Dockerfile inside of 
that folder. There are few sample tools in this repos that you can look at:  
**[fastqc](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)** - 
A quality control tool for high throughput sequence data.  
**[minimap2](https://github.com/lh3/minimap2)** -A versatile sequence alignment 
program that aligns DNA or mRNA sequences against a large reference database.  
**[bwa](https://github.com/lh3/bwa)** - A software package for mapping 
low-divergent sequences against a large reference genome, such as the human 
genome.  
**[gatk](https://gatk.broadinstitute.org/hc/en-us)** - A genomic analysis 
toolkit focused on variant discovery.  
**[picard](https://broadinstitute.github.io/picard/)** - Picard is a set of 
command line tools for manipulating high-throughput sequencing (HTS) data and 
formats such as SAM/BAM/CRAM and VCF.  
**[samtools](https://github.com/samtools/samtools)** - Provide various 
utilities for manipulating alignments in the SAM format, including sorting, 
merging, indexing and generating alignments in a per-position format.


For each of these tools you can find a folder that contains a Dockerfile - 
a docker file to use for the bioinfomatics tool.


### Building a container
This project include a tool to help build a container and push it to 
[Amazon Elastic Container Registry](https://aws.amazon.com/ecr/) (ECR).  
The tool is relying on 2 environment variables ``CDK_DEFAULT_ACCOUNT`` 
(your AWS 12 digit account id) and ``CDK_DEFAULT_REGION`` (the regiong where 
you would like to deploy your pipelione. e.g., us-west-2). You'll need to add 
this parameter to your environment variables (e.g., `~/.bash_profile`).  

To add these parameters to `~/.bash_profile`, open the file and add these 
2 lines and make sure to set the region and account id accordingly.
```
export CDK_DEFAULT_REGION='us-west-2'
export CDK_DEFAULT_ACCOUNT='111111111111'
```
Save the file and run the following command: `source ~/.bash_profile`. This 
will set the environment variabled.

To build the container and push it to ECR use the build.sh script by running 
`./build.sh TOOL_NANE [optional: PROJECT_NAME]` (e.g., `./build.sh fastqc` or 
`./build fastqc my-project-name`).  
The default value for `PROJECT_NAME` is `genomics` which will add the container 
repository under `genomics/TOOL_NANE`

The build tool will first build the bioinformatics docker container and then 
will chain it with `entry.dockerfile` docker container. This container 
overrides the docker `ENTRYPOINT` and introduce a script (`entrypoint.sh`) 
which will act as the docker container `ENTRYPOINT`. This script can copy data 
files from urls and S3 buckets to the local running machine, then execute the 
bioinformatics tool, and at the end will be able to save any output files 
creatd by the running tool back to an S3 bucket.

When submitting a job to run the bioinfomatics tools, you can provide the 
following environment variables that will take care of copying input files to 
the machine and copy output files to S3.  

```
JOB_WORKFLOW_NAME
  Optional
  Name of the parent workflow for this job. 
  Used with JOB_WORKFLOW_EXECUTION_ID to generate a unique prefix for workflow outputs.
  
JOB_WORKFLOW_EXECUTION_ID
  Optional
  Unique identifier for the current workflow run. Used with JOB_WORKFLOW_NAME
  to generate a unique prefix for workflow outputs.
  
JOB_AWS_CLI_PATH
  Required if staging data from S3.
  Default: /opt/aws-cli/bin
  Path to add to the PATH environment variable so that the AWS CLI can be
  located.  Use this if bindmounting the AWS CLI from the host and it is
  packaged in a self-contained way (e.g. not needing OS/distribution 
  specific shared libraries).  The AWS CLI installed with `conda` is
  sufficiently self-contained.  Using a standard python virtualenv does
  not work.
  
JOB_DATA_ISOLATION
  Optional
  Default: null
  Set to 1 if container will need to use an isolated data space - e.g.
  it will operate in a volume mounted from the host for scratch

JOB_INPUTS
  Optional
  Default: null
  A space delimited list of http(s) urls or s3 object urls - e.g.:
    https://somedomain.com/path s3://{prefix1}/{key_pattern1} [s3://{prefix2}/{key_pattern2} [...]]
  for files that the job will use as inputs

JOB_OUTPUTS
  Optional
  Default: null
  A space delimited list of files - e.g.:
    file1 [file2 [...]]
  that the job generates that will be retained - i.e. transferred back to S3

JOB_OUTPUT_PREFIX
  Required if JOB_OUTPUTS need to be stored on S3
  Default: null
    S3 location (e.g. s3://bucket/prefix) were job outputs will be stored

JOB_INPUT_S3_COPY_METHOD
  Optional
  Default: s3cp
  If copying files from an S3 bucket, choose the method for the copy
    s3cp: use s3 cp --no-progress --recursive --exclude "*" --include JOB_INPUT (an s3 input from the JOB_INPUTS)
    s3sync: use s3 sync JOB_INPUT . (for each s3 input from the JOB_INPUTS)

JOB_OUTPUT_S3_COPY_METHOD
  Optional
  Default: s3cp
  If copying files to an S3 bucket, choose the method for the copy
    s3cp: use s3 cp --no-progress file (a file from the JOB_OUTPUTS)
    s3sync: use s3 sync LOCAL_PATH JOB_OUTPUT_PREFIX (Sync a local path to the JOB_OUTPUT_PREFIX location)
```

### Testing the bioinformatics tool
Navigate to the [examples section](SET URL) of this repo.