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

Use the custom AMI script to create an AMI specific to running cromwell tasks
on EC2 instances.

In order for instances launched with this AMI to work with Cromwell, you must
specify the `--scratch-mount-point` as `/cromwell_root` and use the provided
`cromwell-genomics-ami.cloud-init.yaml` as `user-data` when creating the AMI.

```bash
$ ./create-genomics-ami.py \
    --region us-west-2 \
    --key-pair-name my-key-pair \
    --scratch-mount-point /cromwell_root \
    --user-data ./cromwell-genomics-ami.cloud-init.yaml
```

Output from the above command should look like:

```
Using profile: default
Getting security group named: GenomicsAmiSG-subnet-********
Key Pair [ my-key-pair ] exists.
Source AMI ID: ami-093381d21a4fc38d1
Using user-data file:  ./cromwell-genomics-ami.cloud-init.yaml
Creating EC2 instance . done
Getting EC2 instance IP ... [ ***.***.***.*** ]
Checking EC2 Instance health ............................ available and healthy
Creating AMI ........................new AMI [ami-*****************] created.
Terminating instance ...terminated.
Resources that were created on your behalf:

    * AWS Region: us-west-2

    * IAM Instance Profile: GenomicsAMICreationRole_20180827-155952

    * EC2 Key Pair: my-key-pair
    * EC2 Security Group: sg-*****************
    * EC2 Instance ID: i-*****************
    * EC2 AMI ImageId: ami-*****************    <== NOTE THIS ID
        * name: genomics-ami-20180907-153312
        * description: A custom AMI for use with AWS Batch with genomics workflows
```

Once the script completes, you will have a new AMI ID to give to AWS Batch.

## Launch CloudFormation Stacks

To create the remaining pieces of infrastructure:

* S3 Bucket
* IAM Roles
* Batch Compute Environments
* Batch Queues

use the [CloudFormation templates](/aws-batch/configure-aws-batch-cfn) provided in the previous sections.

## Cromwell Server

Since the crucial pieces of AWS infrastructure are an S3 bucket and an AWS Batch
queue, you could run Cromwell as a server on your local machine but configured
to execute jobs on AWS.  However, that means you would have to keep your local
machine (e.g. a laptop), on and connected to the internet until the workflow 
completes.  Thus, it is best to use a remote machine, such as an EC2 instance
as your Cromwell server.

A couple things to note:

* This server does not need to be permanent. In fact,
  when you are not running workflows, you should ideally terminate the instance
  so that you are not paying for resources you are not using.

* You can also launch a Cromwell server just for yourself and exactly when you
  need it.

* This server does not need to be in the same VPC as the one that Batch will
  launch instances in.  However, it would be helpful if you want to debug
  running tasks on task instances.

### Configuring Cromwell on AWS Batch

The following is an example `*.conf` file for Cromwell to use its `AWSBackend`.

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

Install the release of Cromwell you wish to use (this is typically just downloading
a `*.jar` file).

!!! note
    The AWS Backend is only supported on Cromwell 35 and higher

Launch the server using the following command:

```bash
$ java -Dconfig.file=aws.conf -jar cromwell-XX.jar server
```

where `XX` is the version of you installed.

You should now be able to access Cromwell's SwaggerUI from a web browser on
your local machine by navigating to:

[http://localhost:8000/](http://localhost:8000/)

## Running a workflow

### Simple Hello World

```java

task echoHello{
    command {
        echo "Hello AWS!"
    }
    runtime {
        docker: "ubuntu:latest"
        disks: "local-disk"
        memory: "1 GB"
    }

}

workflow printHelloAndGoodbye {
    call echoHello
}

```

### Hello World with inputs

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

```javascript
{
    "wf_hello.hello.addressee": "World!"
}
```