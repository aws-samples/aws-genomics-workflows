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
| -- | -- | :--: | -- |
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
Lets the Cromwell server instance submit and get info about jobs to a specific
AWS Batch job queues.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CromwellServer-BatchPolicy",
            "Effect": "Allow",
            "Action": [
                "batch:DeregisterJobDefinition",
                "batch:TerminateJob",
                "batch:DescribeJobs",
                "batch:CancelJob",
                "batch:SubmitJob",
                "batch:RegisterJobDefinition"
            ],
            "Resource": [
              "<high-priority-queue-arn>",
              "<default-queue-arn>"
            ]
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

#### hello-aws.inputs.json
```json
{
    "wf_hello.hello.addressee": "World!"
}
```

Submit this workflow using:

```bash
$ curl -X POST "http://localhost:8000/api/workflows/v1" \
    -H  "accept: application/json" \
    -F "workflowSource=@hello.wdl" \
    -F "workflowInputs=@hello.inputs"
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