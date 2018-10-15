# Cromwell on AWS Batch

![Cromwell on AWS](./images/cromwell-on-aws_infrastructure.png)

[Cromwell](https://cromwell.readthedocs.io/en/stable/) is a workflow management
system for scientific workflows developed by the [Broad Institute](https://broadinstitute.org/)
and supports job execution using [AWS Batch](https://aws.amazon.com/batch/).

## Prerequisites

To get started using Cromwell on AWS you'll need the following setup in your AWS
account:

* Custom Genomics AMI with Cromwell Additions
* EC2 Instance as a Cromwell Server
* S3 Bucket for inputs and outputs
* IAM Roles for Batch job execution
* AWS Batch
    * Compute Environments
    * Job Queues

The documentation and CloudFormation templates on this site will help you get
these setup.

## Custom AMI with Cromwell Additions

Follow the [instructions on creating a custom AMI](/aws-batch/create-custom-ami/)
with the following changes:

* specify the scratch mount point as `/cromwell_root`
* make sure that cromwell additions are included in the ami
    * select "cromwell" as the AMI type if using the CloudFormation template
    * use `cromwell-genomics-ami.cloud-init.yaml` as `user-data` with the python script

Once complete, you will have a new AMI ID to give to AWS Batch to setup compute environments.

## Launch CloudFormation Stacks

To create the remaining pieces of infrastructure:

* S3 Bucket
* IAM Roles
* Batch Compute Environments
* Batch Queues

use the [CloudFormation templates](/aws-batch/configure-aws-batch-cfn) provided in the previous sections.

## Cromwell Server

To ensure the highest level of security, and robustness for long running workflows,
it is recommended that you use an EC2 instance as your Cromwell server for submitting
workflows to AWS Batch.

A couple things to note:

* This server does not need to be permanent. In fact,
  when you are not running workflows, you should stop or terminate the instance
  so that you are not paying for resources you are not using.

* You can launch a Cromwell server just for yourself and exactly when you need it.

* This server does not need to be in the same VPC as the one that Batch will
  launch instances in.  However, it would be helpful if you want to debug
  running tasks on task instances.

The following CloudFormation template will create a CromwellServer instance with
Cromwell installed and preconfigured to operate with an S3 Bucket and Batch
Queue that you define at launch.

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | :--: |
{{ cfn_stack_row("Cromwell Server", "CromwellServer", "cromwell/cromwell-server.template.yaml", "Create an EC2 instance and an IAM instance profile to run Cromwell") }}

Once the stack is created, you can SSH to the instance and start the server with
the following command:

```bash
$ cd ~
$ ./run_cromwell_server.sh
```

For details of how this instance was constructed - e.g. if you want to customize
it for your purposes, checkout the template source and read the sections below.

### Cromwell server requirements

This instance needs the following:

* Java 8 (per Cromwell's requirements)
* The latest version of Cromwell with AWS Batch backend support (v35+)
* Permissions to
    * read from the S3 bucket used for input and output data
    * submit / describe / cancel / terminate jobs to your AWS Batch queues

The permissions above can be added to the instance via policies in an [instance profile](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html).
Example policies are shown below:

### Access to AWS Batch
Lets the Cromwell server instance submit and get info about AWS Batch jobs.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CromwellServer-BatchPolicy",
            "Effect": "Allow",
            "Action": [
                "batch:DescribeJobQueues"
                "batch:DeregisterJobDefinition"
                "batch:TerminateJob"
                "batch:DescribeJobs"
                "batch:CancelJob"
                "batch:SubmitJob"
                "batch:RegisterJobDefinition"
                "batch:DescribeJobDefinitions"
                "batch:ListJobs"
                "batch:DescribeComputeEnvironments"
            ],
            "Resource": "*"
        }
    ]
}
```

### Access S3
Lets the Cromwell server instance read data from S3 - i.e. the return codes (written
to `rc.txt` files) for each job.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CromwellServer-S3Policy",
            "Effect": "Allow",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::<bucket-name>/*"
        }
    ]
}
```


### Configuring Cromwell on AWS Batch

Log into your server using SSH and create a Cromwell application configuration file.
The following is an example `*.conf` file to use the `AWSBackend`.

```java
// aws.conf
include required(classpath("application"))

aws {
  application-name = "cromwell"
  auths = [{
      name = "default"
      scheme = "default"
  }]
  region = "default"
}

engine {
  filesystems {
    s3 { auth = "default" }
  }
}

backend {
  default = "AWSBATCH"
  providers {
    AWSBATCH {
      actor-factory = "cromwell.backend.impl.aws.AwsBatchBackendLifecycleActorFactory"
      config {
        root = "s3://<your-s3-bucket-name>/cromwell-execution"
        auth = "default"

        numSubmitAttempts = 3
        numCreateDefinitionAttempts = 3

        concurrent-job-limit = 16

        default-runtime-attributes {
          queueArn: "<your-queue-arn>"
        }

        filesystems {
          s3 {
            auth = "default"
          }
        }
      }
    }
  }
}
```

The above file uses the [default credential provider chain](https://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/credentials.html) for authorization.

Replace the following with values appropriate for your account:

* `<your-s3-bucket-name>` : the name of the S3 bucket you will use for inputs
  and outputs from tasks in the workflow.
* `<your-queue-arn>` : the Amazon Resoure Name of the AWS Batch queue you want
  to use for your tasks.

### Start the Cromwell server

Log into your server using SSH.  If you setup a port tunnel, you can interact
with Cromwell's REST API from your local machine:

```bash
$ ssh -L localhost:8000:localhost:8000 ec2-user@<cromwell server host or ip>
```

This port tunnel only needs to be open for submitting workflows.  You do not 
need to be connected to the server while a workflow is running.

Launch the server using the following command:

```bash
$ java -Dconfig.file=aws.conf -jar cromwell-35.jar server
```

!!! note
    If you plan on having this server run for a while, it is recommended you use
    a utility like `screen` or `tmux` so that you can log out while keeping
    Cromwell running.  Alternatively, you could start Cromwell as a detached
    process in the background using `nohup`.

You should now be able to access Cromwell's SwaggerUI from a web browser on
your local machine by navigating to:

[http://localhost:8000/](http://localhost:8000/)

## Running a workflow

To submit a workflow to your Cromwell server, you can use:

* Cromwell's SwaggerUI in a web-browser
* a REST client like [Insomnia](https://insomnia.rest/) or [Postman](https://www.getpostman.com/)
* or, the command line with `curl`

After submitting a workflow, you can monitor the progress of tasks via the
AWS Batch console.

Some example workflows you can test with are shown below.

### Simple Hello World

This is a single file workflow.  It simply echos "Hello AWS!" to `stdout` and exits.

#### simple-hello.wdl
```java
task echoHello{
    command {
        echo "Hello AWS!"
    }
    runtime {
        docker: "ubuntu:latest"
    }

}

workflow printHelloAndGoodbye {
    call echoHello
}

```

To submit this workflow via `curl` use the following command:

```bash
$ curl -X POST "http://localhost:8000/api/workflows/v1" \
    -H  "accept: application/json" \
    -F "workflowSource=@/path/to/simple-hello.wdl"
```

You should receive a response like the following:

```json
{"id":"104d9ade-6461-40e7-bc4e-227c3a49e98b","status":"Submitted"}
```

If the workflow completes successfully, the server will log the following:

```
2018-09-21 04:07:42,928 cromwell-system-akka.dispatchers.engine-dispatcher-25 INFO  - WorkflowExecutionActor-7eefeeed-157e-4307-9267-9b4d716874e5 [UUID(7eefeeed)]: Workflow w complete. Final Outputs:
{
  "w.echo.f": "s3://aws-cromwell-test-us-east-1/cromwell-execution/w/7eefeeed-157e-4307-9267-9b4d716874e5/call-echo/echo-stdout.log"
}
2018-09-21 04:07:42,931 cromwell-system-akka.dispatchers.engine-dispatcher-25 INFO  - WorkflowManagerActor WorkflowActor-7eefeeed-157e-4307-9267-9b4d716874e5 is in a terminal state: WorkflowSucceededState
```

### Hello World with inputs

This workflow is virtually the same as the single file workflow above, but
uses an input file to define parameters in the workflow.

#### hello-aws.wdl
```java
task hello {
  String addressee
  command {
    echo "Hello ${addressee}! Welcome to Cromwell . . . on AWS!"
  }
  output {
    String message = read_string(stdout())
  }
  runtime {
    docker: "ubuntu:latest"
  }
}

workflow wf_hello {
  call hello

  output {
     hello.message
  }
}
```

#### hello-aws.json
```json
{
    "wf_hello.hello.addressee": "World!"
}
```

Submit this workflow using:

```bash
$ curl -X POST "http://localhost:8000/api/workflows/v1" \
    -H  "accept: application/json" \
    -F "workflowSource=@hello-aws.wdl" \
    -F "workflowInputs=@hello-aws.json"
```

### Using data on S3

This workflow demonstrates how to use data from S3.

First, create some data:

```bash
$ curl "https://baconipsum.com/api/?type=all-meat&paras=1&format=text" > meats.txt
```

and upload it to your S3 bucket:


```bash
$ aws s3 cp meats.txt s3://<your-bucket-name>/
```

Create the following `wdl` and input `json` files.

#### s3inputs.wdl

```java
task read_file {
  File file

  command {
    cat ${file}
  }

  output {
    String contents = read_string(stdout())
  }

  runtime {
    docker: "ubuntu:latest"
  }
}

workflow ReadFile {
  call read_file

  output {
    read_file.contents
  }
}
```

#### s3inputs.json

```json
{
  "ReadFile.read_file.file": "s3://aws-cromwell-test-us-east-1/meats.txt"
}
```

Submit the workflow via `curl`:

```bash
$ curl -X POST "http://localhost:8000/api/workflows/v1" \
    -H  "accept: application/json" \
    -F "workflowSource=@s3inputs.wdl" \
    -F "workflowInputs=@s3inputs.json"
```

If successful the server should log the following:

```
2018-09-21 05:04:15,478 cromwell-system-akka.dispatchers.engine-dispatcher-25 INFO  - WorkflowExecutionActor-1774c9a2-12bf-42ea-902d-3dbe2a70a116 [UUID(1774c9a2)]: Workflow ReadFile complete. Final Outputs:
{
  "ReadFile.read_file.contents": "Strip steak venison leberkas sausage fatback pork belly short ribs.  Tail fatback prosciutto meatball sausage filet mignon tri-tip porchetta cupim doner boudin.  Meatloaf jerky short loin turkey beef kielbasa kevin cupim burgdoggen short ribs spare ribs flank doner chuck.  Cupim prosciutto jerky leberkas pork loin pastrami.  Chuck ham pork loin, prosciutto filet mignon kevin brisket corned beef short loin shoulder jowl porchetta venison.  Hamburger ham hock tail swine andouille beef ribs t-bone turducken tenderloin burgdoggen capicola frankfurter sirloin ham."
}
2018-09-21 05:04:15,481 cromwell-system-akka.dispatchers.engine-dispatcher-28 INFO  - WorkflowManagerActor WorkflowActor-1774c9a2-12bf-42ea-902d-3dbe2a70a116 is in a terminal state: WorkflowSucceededState
```

### Real-world example: HaplotypeCaller

This example demonstrates how to use Cromwell with the AWS backend to run GATK4 
HaplotypeCaller against public data in S3.  The HaplotypeCaller tool is one of the
primary steps in GATK best practices pipeline.

The source for thse files can be found in [Cromwell's test suite on GitHub](https://github.com/broadinstitute/cromwell/tree/develop/centaur/src/main/resources/integrationTestCases/germline/haplotype-caller-workflow).

#### Worflow Definition

`HaplotypeCaller.aws.wdl`

```wdl
## Copyright Broad Institute, 2017
##
## This WDL workflow runs HaplotypeCaller from GATK4 in GVCF mode on a single sample
## according to the GATK Best Practices (June 2016), scattered across intervals.
##
## Requirements/expectations :
## - One analysis-ready BAM file for a single sample (as identified in RG:SM)
## - Set of variant calling intervals lists for the scatter, provided in a file
##
## Outputs :
## - One GVCF file and its index
##
## Cromwell version support
## - Successfully tested on v29
## - Does not work on versions < v23 due to output syntax
##
## IMPORTANT NOTE: HaplotypeCaller in GATK4 is still in evaluation phase and should not
## be used in production until it has been fully vetted. In the meantime, use the GATK3
## version for any production needs.
##
## Runtime parameters are optimized for Broad's Google Cloud Platform implementation.
##
## LICENSING :
## This script is released under the WDL source code license (BSD-3) (see LICENSE in
## https://github.com/broadinstitute/wdl). Note however that the programs it calls may
## be subject to different licenses. Users are responsible for checking that they are
## authorized to run all programs before running this script. Please see the dockers
## for detailed licensing information pertaining to the included programs.

# WORKFLOW DEFINITION
workflow HaplotypeCallerGvcf_GATK4 {
  File input_bam
  File input_bam_index
  File ref_dict
  File ref_fasta
  File ref_fasta_index
  File scattered_calling_intervals_list

  String gatk_docker

  String gatk_path

  Array[File] scattered_calling_intervals = read_lines(scattered_calling_intervals_list)

  String sample_basename = basename(input_bam, ".bam")

  String gvcf_name = sample_basename + ".g.vcf.gz"
  String gvcf_index = sample_basename + ".g.vcf.gz.tbi"

  # Call variants in parallel over grouped calling intervals
  scatter (interval_file in scattered_calling_intervals) {

    # Generate GVCF by interval
    call HaplotypeCaller {
      input:
        input_bam = input_bam,
        input_bam_index = input_bam_index,
        interval_list = interval_file,
        gvcf_name = gvcf_name,
        ref_dict = ref_dict,
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        docker_image = gatk_docker,
        gatk_path = gatk_path
    }
  }

  # Merge per-interval GVCFs
  call MergeGVCFs {
    input:
      input_vcfs = HaplotypeCaller.output_gvcf,
      vcf_name = gvcf_name,
      vcf_index = gvcf_index,
      docker_image = gatk_docker,
      gatk_path = gatk_path
  }

  # Outputs that will be retained when execution is complete
  output {
    File output_merged_gvcf = MergeGVCFs.output_vcf
    File output_merged_gvcf_index = MergeGVCFs.output_vcf_index
  }
}

# TASK DEFINITIONS

# HaplotypeCaller per-sample in GVCF mode
task HaplotypeCaller {
  File input_bam
  File input_bam_index
  String gvcf_name
  File ref_dict
  File ref_fasta
  File ref_fasta_index
  File interval_list
  Int? interval_padding
  Float? contamination
  Int? max_alt_alleles

  Int preemptible_tries
  Int disk_size
  String mem_size

  String docker_image
  String gatk_path
  String java_opt

  command {
    ${gatk_path} --java-options ${java_opt} \
      HaplotypeCaller \
      -R ${ref_fasta} \
      -I ${input_bam} \
      -O ${gvcf_name} \
      -L ${interval_list} \
      -ip ${default=100 interval_padding} \
      -contamination ${default=0 contamination} \
      --max-alternate-alleles ${default=3 max_alt_alleles} \
      -ERC GVCF
  }

  runtime {
    docker: docker_image
    memory: mem_size
    cpu: 1
    disks: "local-disk"
  }

  output {
    File output_gvcf = "${gvcf_name}"
  }
}

# Merge GVCFs generated per-interval for the same sample
task MergeGVCFs {
  Array [File] input_vcfs
  String vcf_name
  String vcf_index

  Int preemptible_tries
  Int disk_size
  String mem_size

  String docker_image
  String gatk_path
  String java_opt

  command {
    ${gatk_path} --java-options ${java_opt} \
      MergeVcfs \
      --INPUT=${sep=' --INPUT=' input_vcfs} \
      --OUTPUT=${vcf_name}
  }

  runtime {
    docker: docker_image
    memory: mem_size
    cpu: 1
    disks: "local-disk"
}

  output {
    File output_vcf = "${vcf_name}"
    File output_vcf_index = "${vcf_index}"
  }
}
```

#### Inputs

The inputs for this workflow reference public data on S3 that is hosted by AWS as
part of the AWS Open Data Program.

`HaplotypeCaller.aws.json`

```json
{
  "##_COMMENT1": "INPUT BAM",
  "HaplotypeCallerGvcf_GATK4.input_bam": "s3://gatk-test-data/wgs_bam/NA12878_24RG_hg38/NA12878_24RG_small.hg38.bam",
  "HaplotypeCallerGvcf_GATK4.input_bam_index": "s3://gatk-test-data/wgs_bam/NA12878_24RG_hg38/NA12878_24RG_small.hg38.bai",

  "##_COMMENT2": "REFERENCE FILES",
  "HaplotypeCallerGvcf_GATK4.ref_dict": "s3://broad-references/hg38/v0/Homo_sapiens_assembly38.dict",
  "HaplotypeCallerGvcf_GATK4.ref_fasta": "s3://broad-references/hg38/v0/Homo_sapiens_assembly38.fasta",
  "HaplotypeCallerGvcf_GATK4.ref_fasta_index": "s3://broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.fai",

  "##_COMMENT3": "INTERVALS",
  "HaplotypeCallerGvcf_GATK4.scattered_calling_intervals_list": "s3://gatk-test-data/intervals/hg38_wgs_scattered_calling_intervals.txt",
  "HaplotypeCallerGvcf_GATK4.HaplotypeCaller.interval_padding": 100,

  "##_COMMENT4": "DOCKERS",
  "HaplotypeCallerGvcf_GATK4.gatk_docker": "broadinstitute/gatk:4.0.0.0",

  "##_COMMENT5": "PATHS",
  "HaplotypeCallerGvcf_GATK4.gatk_path": "/gatk/gatk",

  "##_COMMENT6": "JAVA OPTIONS",
  "HaplotypeCallerGvcf_GATK4.HaplotypeCaller.java_opt": "-Xms8000m",
  "HaplotypeCallerGvcf_GATK4.MergeGVCFs.java_opt": "-Xms8000m",

  "##_COMMENT7": "MEMORY ALLOCATION",
  "HaplotypeCallerGvcf_GATK4.HaplotypeCaller.mem_size": "10 GB",
  "HaplotypeCallerGvcf_GATK4.MergeGVCFs.mem_size": "30 GB",

  "##_COMMENT8": "DISK SIZE ALLOCATION",
  "HaplotypeCallerGvcf_GATK4.HaplotypeCaller.disk_size": 100,
  "HaplotypeCallerGvcf_GATK4.MergeGVCFs.disk_size": 100,

  "##_COMMENT9": "PREEMPTION",
  "HaplotypeCallerGvcf_GATK4.HaplotypeCaller.preemptible_tries": 3,
  "HaplotypeCallerGvcf_GATK4.MergeGVCFs.preemptible_tries": 3
}
```

Submit the workflow via `curl`:

```bash
$ curl -X POST "http://localhost:8000/api/workflows/v1" \
    -H  "accept: application/json" \
    -F "workflowSource=@HaplotypeCaller.aws.wdl" \
    -F "workflowInputs=@HaplotypeCaller.aws.json"
```

This workflow takes about 60-90min to complete.