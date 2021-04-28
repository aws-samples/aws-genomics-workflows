# Bioinformatics tools examples

After [deploying the CDK genomics pipeline project](GITHUB URL) you could test 
the genomics tools directly with AWS Batch or start a Step Functions pipeline.


### Testing bioinformatics tools using AWS Batch
Create a file named batch-TOOL_NANE.json.
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
                "name": "JOB_OUTPUTS",
                "value": ""
            },
            {
                "name": "JOB_OUTPUT_PREFIX",
                "value": ""
            }
        ]
    }
}

```

**jobName** (string)  
The name of the job. The first character must be alphanumeric, and up to 128 
letters (uppercase and lowercase), numbers, hyphens, and underscores are 
allowed.

**jobQueue** (string)  
The [job queue](https://docs.aws.amazon.com/batch/latest/userguide/job_queues.html) 
into which the job is submitted. You can specify either the name or the Amazon 
Resource Name (ARN) of the queue.

**jobDefinition** (string)  
The [job definition](https://docs.aws.amazon.com/batch/latest/userguide/job_definitions.html) 
used by this job. This value can be one of name , name:revision , or the Amazon 
Resource Name (ARN) for the job definition. If name is specified without 
a revision then the latest active revision is used.

**containerOverrides.vcpus** (integer optional)  
The number of vCPUs to reserve for the container. This value overrides the 
value set in the job definition.

**containerOverrides.memory** (integer optional)  
The number of MiB of memory reserved for the job. This value overrides the 
value set in the job definition.

**containerOverrides.command** (list)  
The command to send to the container that overrides the default command from 
the Docker image or the job definition.

**containerOverrides.environment** (list)  
The environment variables to send to the container. You can add new environment 
variables, which are added to the container at launch, or you can override the 
existing environment variables from the Docker image or the job definition.  
(structure)  
A key-value pair object.  
**name** (string)  
The name of the key-value pair. For environment variables, this is the name of 
the environment variable.  
**value** (string)  
The value of the key-value pair. For environment variables, this is the value 
of the environment variable.

Example for a `batch-fastqc.json`
```
{
    "jobName": "fastqc",
    "jobQueue": "genomics-default-queue",
    "jobDefinition": "genomics-fastqc:1",
    "containerOverrides": {
        "vcpus": 1,
        "memory": 1000,
        "command": ["fastqc *.gz"],
        "environment": [{
                "name": "JOB_INPUTS",
                "value": "s3://aws-batch-genomics-shared/secondary-analysis/example-files/fastq/NIST7035_R*.fastq.gz"
            },
            {
                "name": "JOB_OUTPUTS",
                "value": "*.html *.zip"
            },
            {
                "name": "JOB_OUTPUT_PREFIX",
                "value": "s3://my-genomics-bucket-name/some-folder-name"
            }
        ]
    }
}

```
In this example we are running the FastQC tools that will take fastq files and 
generate a report. It will output zip and html files which we will save to an 
S3 bucket.  
**jobName** - "fastqc". A name that describe the job to be run.  
**jobQueue** - "genomics-default-queue". A valid name of a job queue. This 
could be found in the AWS web console > Batch > Job queues.  
**jobDefinition** - "genomics-fastqc:1". A valid and active job definition and 
it's version. This could be found in the AWS web console > Batch > Job 
definitions.  
**containerOverrides.vcpus** - 1. Request a machine that has at least 1 core.  
**containerOverrides.memory** - 1000. Request a machine that has at least 
1000MiB of RAM.  
**containerOverrides.command** - ["fastqc *.gz"]. Run the fastq command on all 
the .gz files in the working directory.  
**containerOverrides.environment** - A list of key-value pairs.

**name**: JOB_INPUTS.  
**value**: fastq files from a source S3 bucket

**name**: JOB_OUTPUTS.  
**value**: "*.html *.zip". Copy all html and zip files from a local directory 
to an S3 bucket.

**name**: JOB_OUTPUT_PREFIX.  
**value**: An S3 bucket and a prefix (folder) to copy the output files into.


There are several examples under the `examples` directory. To run an example, 
edit the example file you want to run (e.g., `examples/batch-fastqc-job.json`),
update the `JOB_INPUTS` to a valid source of your sample fastq files, or leave 
the default value to use a demo sample. Update the `JOB_OUTPUT_PREFIX` to a 
valid s3 bucket and a subfolder where you want the output zip and html files 
to be saved to.

Change directory to the examples directory and then submit the job to Batch.

```
cd examples
aws batch submit-job --cli-input-json file://batch-fastqc-job.json
```

Navigate to the Batch jobs page (AWS console -> AWS Batch -> Jobs -> select the 
job queue you used (e.g., `genomics-default-queue`) to track the progress of 
the job. You can click on the job name and them click on the Log stream name 
link to track the stdout on the running task.
