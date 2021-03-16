# Bioinformatics tools examples

You can test the bioinfomatics tools with AWS Batch directly or start a full Step Functions pipeline.

**jobName** - A name for the job, this will appear in the AWS Batch Job list  
**jobQueue** - The name of the queue you want to use in AWS Batch. You can get this name from the AWS Batch console > 
Job queues.  
**jobDefinition** - The AWS Batch job definition including a version number. You can get this name from the AWS Batch console > 
Job definitions.  
**containerOverrides.vcpus** - The desired amount of vcpus to run this job.  
**containerOverrides.memory** - The number of MiB of memory reserved for the job.  
**containerOverrides.command** - The command to be executed.  
**containerOverrides.environment** - Environment variables to send to the container. Refer to the special environment 
variables in the [containers readme file](../README.md). 

Change the "JOB_OUTPUT_PREFIX" parameter to an existing bucket and choose a prefix (e.g., s3://mybucketname/test).

### FastQC
To run the command, cd to the examples directory (e.g., ``cd src/aws-genomics-cdk/examples``) and run the following 
command ``aws batch submit-job --cli-input-json file://batch-fastqc-job.json``  
If the job finish successfully you should see new html and zip files in the S3 location you configured.

```
batch-fastqc-job.json
{
    "jobName": "fastqc",
    "jobQueue": "genomics-default-job-queue",
    "jobDefinition": "genomics-fastqc:1",
    "containerOverrides": {
        "vcpus": 2,
        "memory": 4000,
        "command": ["fastqc *.gz"],
        "environment": [{
                "name": "JOB_INPUTS",
                "value": "s3://aws-batch-genomics-shared/secondary-analysis/example-files/fastq/NIST7035_R1_trim_samp-0p1.fastq.gz s3://aws-batch-genomics-shared/secondary-analysis/example-files/fastq/NIST7035_R2_trim_samp-0p1.fastq.gz"
            },
            {
                "name": "JOB_OUTPUTS",
                "value": "*.html *.zip"
            },
            {
                "name": "JOB_OUTPUT_PREFIX",
                "value": "s3://[YOUR BUCKET NAME]/[SOME PREFIX]"
            },
            {
                "name": "JOB_AWS_CLI_PATH",
                "value": "/opt/aws-cli/bin"
            }
        ]
    }
}

```


### Minimap2
To run the command, cd to the examples directory (e.g., ``cd src/aws-genomics-cdk/examples``) and run the following 
command ``aws batch submit-job --cli-input-json file://batch-minimap2-job.json``  
If the job finish successfully you should see new sam files in the S3 location you configured.
```
batch-minimap2-job.json
{
    "jobName": "minimap2",
    "jobQueue": "genomics-default-queue",
    "jobDefinition": "minimap2:1",
    "containerOverrides": {
        "vcpus": 8,
        "memory": 16000,
        "command": ["minimap2 -ax map-pb Homo_sapiens_assembly38.fasta NIST7035_R1_trim_samp-0p1.fastq.gz > NIST7035.sam"],
        "environment": [{
            "name": "JOB_INPUTS",
            "value": "s3://broad-references/hg38/v0/Homo_sapiens_assembly38.fasta s3://aws-batch-genomics-shared/secondary-analysis/example-files/fastq/NIST7035_R1_trim_samp-0p1.fastq.gz"
        },
        {
            "name": "JOB_OUTPUTS",
            "value": "*.sam"
        },
        {
            "name": "JOB_OUTPUT_PREFIX",
            "value": "s3://[YOUR BUCKET NAME]/[SOME PREFIX]"
        },
        {
            "name": "JOB_AWS_CLI_PATH",
            "value": "/opt/aws-cli/bin"
        }
        ]
    }
}
```


### A demo pipeline that runs FasqQC and then Minimap2

Logon to the AWS console, navigate to Step Functions and click on the "genomics-pipelines-state-machine" state machine.  
Click on the "Start execution" button and use the following json content for the input section. Change the 
"JOB_OUTPUT_PREFIX" parameter to an existing bucket and choose a prefix (e.g., s3://mybucketname/test).
```
{
  "params": {
	"environment": {
		"JOB_OUTPUT_PREFIX": "[YOUR BUCKET NAME]/[SOME PREFIX]"
	},
	"fastqc": {
		"input": "s3://aws-batch-genomics-shared/secondary-analysis/example-files/fastq/NIST7035_R1_trim_samp-0p1.fastq.gz s3://aws-batch-genomics-shared/secondary-analysis/example-files/fastq/NIST7035_R2_trim_samp-0p1.fastq.gz",
		"output": "*.html *.zip"
	},
	"minimap2": {
		"input": "s3://broad-references/hg38/v0/Homo_sapiens_assembly38.fasta s3://aws-batch-genomics-shared/secondary-analysis/example-files/fastq/NIST7035_R1_trim_samp-0p1.fastq.gz",
		"fastaFileName": "Homo_sapiens_assembly38.fasta",
		"fastqFiles": "NIST7035_R1_trim_samp-0p1.fastq.gz",
		"samOutput": "hg38-NIST7035.sam",
		"output": "*.sam"
	}
  }
}
```