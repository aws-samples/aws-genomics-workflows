# Setting up bioinformatics containers

The CDK genomics pipeline project is leveraging [AWS Batch](https://aws.amazon.com/batch/) for 
running bioinformatics jobs. AWS Batch works with docker containers which means we'll need to
build or use an existing docker container with the bioinfomatics tools installed.

Start by creating a folder for your tool and place the Dockerfile inside of that folder.
There are few sample tools in this repos that you can look at:  
**copy** - A tool for testing the system without the need to run any bioinfomatics tools.  
**fastqc** - A quality control tool for high throughput sequence data. [Tool reference](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)  
**minimap2** - Minimap2 is a versatile sequence alignment program that aligns DNA or mRNA sequences against a large reference database. [Tool reference](https://github.com/lh3/minimap2)

For each of these tools you can find a folder that contains 2 files - Dockerfile and job.json  
**Dockerfile** - The docker file to use for the bioinfomatics tool  
**job.json** - A sample job you can use to test the tool with AWS bath. To run AWS batch command to test a job use the 
follwing command: `aws batch submit-job --cli-input-json file://job.json`


### Building a container
This project include a tool to help build a container and push it to [Amazon Elastic Container Registry](https://aws.amazon.com/ecr/) (ECR)
The tool is relying on 2 environment variables CDK_DEFAULT_ACCOUNT (your AWS 12 digit account id) and 
CDK_DEFAULT_REGION (the regiong where you would like to deploy your pipelione. e.g., us-west-2). You'll need to add this parameter 
to your environment variables (e.g., `~/.bash_profile`).  
To add these parameters to `~/.bash_profile`, open the file and add these 2 lines and make sure to set the region and account id 
accordingly.
```
export CDK_DEFAULT_REGION='us-west-2'
export CDK_DEFAULT_ACCOUNT='111111111111'
```
Save the file and run the following command: `source ~/.bash_profile`. This will set the environment variabled.

To build the container and push it to ECR use the build.sh script by running `./build.sh TOOL_NANE` (e.g., `./build.sh fastqc`).

The build tool will first build the bioinformatics docker container and then will chain it with `entry.dockerfile` docker container. 
This container overrides the docker `ENTRYPOINT` and introduce a script (`entrypoint.sh`) which will act as the docker 
container `ENTRYPOINT`. This script can copy data files from urls and S3 buckets to the local running machine, then execute the 
bioinformatics tool, and at the end will be able to save any output files creatd by the running tool back to an S3 bucket.

When submitting a job to run the bioinfomatics tools, you can provide the following environment variables that will take 
care of copying input files to the machine and copy output files to S3.  

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
After [deploying the CDK genomics pipeline project](GITHUB URL) you could test the genomics tools directly with AWS Batch. 
Create a file named job.json in the folder of the bioinformatics tool (the same folder where you places the Dockerfile) 

```
{
    "jobName": "",
    "jobQueue": "",
    "jobDefinition": "",
    "containerOverrides": {
        "vcpus": 1,
        "memory": 1000,
        "command": [""],
        "environment": [{
                "name": "JOB_INPUTS",
                "value": ""
            },
            {
                "name": "JOB_INPUT_S3_COPY_METHOD",
                "value": ""
            },
            {
                "name": "JOB_OUTPUTS",
                "value": ""
            },
            {
                "name": "JOB_OUTPUT_S3_COPY_METHOD",
                "value": ""
            },
            {
                "name": "JOB_OUTPUT_PREFIX",
                "value": ""
            },
            {
                "name": "JOB_AWS_CLI_PATH",
                "value": "/opt/aws-cli/bin"
            }
        ]
    }
}

```

**jobName** (string)  
The name of the job. The first character must be alphanumeric, and up to 128 letters (uppercase and lowercase), 
numbers, hyphens, and underscores are allowed.

**jobQueue** (string)  
The [job queue](https://docs.aws.amazon.com/batch/latest/userguide/job_queues.html) into which the job is submitted. 
You can specify either the name or the Amazon Resource Name (ARN) of the queue.

**jobDefinition** (string)  
The [job definition](https://docs.aws.amazon.com/batch/latest/userguide/job_definitions.html) used by this job. 
This value can be one of name , name:revision , or the Amazon Resource Name (ARN) for the job definition. If name is 
specified without a revision then the latest active revision is used.

**containerOverrides.vcpus** (integer)  
The number of vCPUs to reserve for the container. This value overrides the value set in the job definition.

**containerOverrides.memory** (integer)  
The number of MiB of memory reserved for the job. This value overrides the value set in the job definition.

**containerOverrides.command** (list)  
The command to send to the container that overrides the default command from the Docker image or the job definition.

**containerOverrides.environment** (list)  
The environment variables to send to the container. You can add new environment variables, which are added to the 
container at launch, or you can override the existing environment variables from the Docker image or the job definition.  
(structure)  
A key-value pair object.  
**name** (string)  
The name of the key-value pair. For environment variables, this is the name of the environment variable.  
**value** (string)  
The value of the key-value pair. For environment variables, this is the value of the environment variable.

Example for a job.json
```
{
    "jobName": "fastqc",
    "jobQueue": "genomics-default-queue",
    "jobDefinition": "genomics-fastqc:1",
    "containerOverrides": {
        "vcpus": 8,
        "memory": 16000,
        "command": ["fastqc *.gz"],
        "environment": [{
                "name": "JOB_INPUTS",
                "value": "s3://aws-batch-genomics-shared/secondary-analysis/example-files/fastq/NIST7035_R1_trim_samp-0p1.fastq.gz s3://aws-batch-genomics-shared/secondary-analysis/example-files/fastq/NIST7035_R2_trim_samp-0p1.fastq.gz"
            },
            {
                "name": "JOB_INPUT_S3_COPY_METHOD",
                "value": "s3cp"
            },
            {
                "name": "JOB_OUTPUTS",
                "value": "*.html *.zip"
            },
            {
                "name": "JOB_OUTPUT_S3_COPY_METHOD",
                "value": "s3cp"
            },
            {
                "name": "JOB_OUTPUT_PREFIX",
                "value": "s3://my-genomics-bucket-name/some-folder-name"
            },
            {
                "name": "JOB_AWS_CLI_PATH",
                "value": v
            }
        ]
    }
}

```
In this example we are running the FastQC tools that will take fastq files and generate a report. It will output zip and 
html files which we will save to an S3 bucket.  
**jobName** - "fastqc". A name that describe the job to be run.  
**jobQueue** - "genomics-default-queue". A valid name of a job queue. This could be found in the AWS web console > 
Batch > Job queues.  
**jobDefinition** - "genomics-fastqc:1". A valid and active job definition and it's version. This could be found in the 
AWS web console > Batch > Job definitions.  
**containerOverrides.vcpus**  - 8. Request a machine that has at least 8 cores.  
**containerOverrides.memory** - 16000. Request a machine that has at least 16GiB of RAM.  
**containerOverrides.command** - ["fastqc *.gz"]. Run the fastq command on all the .gz files in the working directory.  
**containerOverrides.environment** - A list of key-value pairs.

**name**: JOB_INPUTS.  
**value**: fastq files from an S3 bucket

**name**: JOB_INPUT_S3_COPY_METHOD  
**value**: "s3cp. Use the aws s3 cp command to copy files from an S3 bucket to the a local directory.

**name**: JOB_OUTPUTS.  
**value**: "*.html *.zip". Copy all html and zip files from a local directory to an S3 bucket.

**name**: JOB_OUTPUT_S3_COPY_METHOD.  
**value**: "s3cp". Use the aws s3 cp command to copy files from a local directory to an S3 bucket.

**name**: JOB_OUTPUT_PREFIX.  
**value**: An S3 bucket and a prefix (folder) to copy the output files into.

**name**: JOB_AWS_CLI_PATH.  
**value**: "/opt/aws-cli/bin". Path to add to the PATH environment variable so that the AWS CLI can be located

To run AWS batch command to test a job use the follwing command: `aws batch submit-job --cli-input-json file://job.json`