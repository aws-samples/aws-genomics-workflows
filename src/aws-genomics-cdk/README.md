# Genomics Workflows on AWS - CDK code

Contained herein is a CDK application for creating AWS resources for working with large-scale biomedical data - e.g. genomics.  

In order to deploy this CDK application, you'll need an environment with AWS CLI access and AWS CDK installed. A quick 
way yo get an environment for running this application is to launch [AWS Cloud9](https://aws.amazon.com/cloud9/).  

AWS Cloud9 is a cloud-based integrated development environment (IDE) that lets you write, run, and debug your code 
with just a browser. It includes a code editor, debugger, and terminal. Cloud9 comes prepackaged with essential 
tools for popular programming languages, including JavaScript, Python, PHP, and more, so you don’t need to install 
files or configure your development machine to start new projects.


## Download

Clone the repo to your local environment / Cloud9 environment.
```
git clone https://github.com/aws-samples/aws-genomics-workflows.git
```

## Configure

This CDK application requires an S3 bucket and a VPC. The application can create them as part of the deployment or 
you could configure the application to use your own S3 bucket and/or existing VPC.

After cloning the repo, open, update, and save the application configuration file - `app.config.json`.

**accountID** - Your [AWS account id](https://docs.aws.amazon.com/IAM/latest/UserGuide/console_account-alias.html).  
**region** - The [AWS region](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) 
you want to use for the deployment (e.g., us-east-1, us-west-2, etc.).
**S3.existingBucket** - If you want to use an existing bucket, set this value to true, otherwise set it to false to 
create a new bucket.  
**S3.bucketName** - The bucket name to use or create.  
**VPC.createVPC** - If you want to create a new VPC, set this to true, otherwise set to false.  
**VPC.existingVPCName** - If you set the createVPC option to false, you must provide a valid VPC name to use in the 
same region of the deployment.  
**VPC.maxAZs** - The amount of availability zones to use when creating a new VPC.  
**VPC.cidr** - The [CIDR block](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing) for the new VPC.  
**VPC.cidrMask** - The [CIDR block subnet mask](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing#Subnet_masks) 
for the new VPC.  
**batch.defaultVolumeSize** - The default EBS volume size in GiB to be attached to the EC2 instance under AWS Batch.  
**batch.spotMaxVCPUs** - The limit on vcpus when using [spot instances](https://aws.amazon.com/ec2/spot/).  
**batch.onDemendMaxVCPUs** - The limit on vcpus when using on-demand instances.  
**batch.instanceTypes** - The [EC2 instance types](https://aws.amazon.com/ec2/instance-types/) to use in AWS Batch.  
**stepFunctions.launchDemoPipeline** - If set to true, the application will deploy a demo pipeline using step fuinctions.  
**stepFunctions.jobDefinitions** - List of parametrs for the demo application bioinformatics tools.
```
{
    "accountID": "111111111111",
    "region": "us-west-2",
    "S3": {
        "existingBucket": true,
        "bucketName": ""
    },
    "VPC": {
        "createVPC": true,
        "existingVPCName": "",
        "maxAZs": 2,
        "cidr": "10.0.0.0/16",
        "cidrMask": 24
    },
    "batch": {
        "defaultVolumeSize": 100,
        "spotMaxVCPUs": 128,
        "onDemendMaxVCPUs": 128,
        "instanceTypes": [
            "c4.large",
            "c4.xlarge",
            "c4.2xlarge",
            "c4.4xlarge",
            "c4.8xlarge",
            "c5.large",
            "c5.xlarge",
            "c5.2xlarge",
            "c5.4xlarge",
            "c5.9xlarge",
            "c5.12xlarge",
            "c5.18xlarge",
            "c5.24xlarge"
        ]
    },
    "stepFunctions": {
        "launchDemoPipeline": true,
        "jobDefinitions": {
            "fastqc": {
                "repository": "genomics/fastqc",
                "memoryLimit": 8000,
                "vcpus": 4,
                "spot": true,
                "retryAttempts":1,
                "timeout": 600
            },
            "minimap2": {
                "repository": "genomics/minimap2",
                "memoryLimit": 16000,
                "vcpus": 8,
                "spot": true,
                "retryAttempts":1,
                "timeout": 3600
            }
        }
    }
}
```

## Deploy

To deploy the CDK application, use the command line and make sure you are in the root folder of the CDK application. 
(`src/aws-genomics-cdk`).  
First install the neccessary node.js modules
```
npm install
```

Then deploy the application.
```
# The "--require-approval never" parameter will skip the question to approve specific resouce creation, 
# such as IAM roles. You can remove this parameter if you want to be prompted to approve creating these 
# resources.
cdk deploy --all --require-approval never
```


## Stacks

| File | Description |
| :--- | :---------- |
| `lib/aws-genomics-cdk-stack.ts` | The main stack that initialize the rest of the stacks |
| `lib/vpc/vpc-stack.ts` | An optional stack that will launch a VPC |
| `lib/batch/batch-stack.ts` | An AWS Batch stack with 2 comnpute environments (spot and on demand) and 2 queues (default and high priority) |
| `lib/batch/batch-iam-stack.ts` | An IAM stack with roles and policies required for running AWS Batch |
| `lid/step-fuinctions/genomics-state-machine-stack.ts` | A step function demo of running a pipeline |


## Constructs

| File | Description |
| :--- | :---------- |
| `lib/batch/batch-compute-environmnet-construct.ts` | A construct for creating an [AWS Batch compute environment](https://docs.aws.amazon.com/batch/latest/userguide/compute_environments.html) |
| `lib/batch/job-queue-construct.ts` | A construct for creating an [AWS Batch job queue](https://docs.aws.amazon.com/batch/latest/userguide/job_queues.html) |
| `lib/batch/launch-template-construct.ts` | A construct for creating an [EC2 launch template](https://docs.aws.amazon.com/autoscaling/ec2/userguide/LaunchTemplates.html) |
| `lib/step-functions/genomics-task-construct.ts` | A construct for creating a step function task that submits a batch job |
| `lib/step-functions/job-definition-construct.ts` | A construct for creating an [AWS Batch job definition](https://docs.aws.amazon.com/batch/latest/userguide/job_definitions.html) to be used as a task in step functions |

