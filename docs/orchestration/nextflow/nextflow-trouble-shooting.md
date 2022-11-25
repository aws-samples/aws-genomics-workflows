# Nextflow Troubleshooting

The following are some common errors that we have seen and suggested solutions

## Job Logs say there is an error in AWS CLI while loading shared libraries
### Possible Cause(s)
Nextflow on AWS Batch relies on the process containers being able to use the AWS CLI (which is mounted from the container host).
Very minimal container images such as Alpine do not contain the `glibc` libraries needed by the AWS CLI.

### Suggested Solution(s)

 * Modify your image to include or mount these dependencies
 * Use an image (or build from a base) that already contains these such as `ubuntu:latest`

## AWS credentials not working when set in the environment
### Possible Cause(s)
You are using temporary federated or IAM role temporary credentials that use the AWS_SESSION_TOKEN in addition to AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY. Nextflow does not look for the AWS_SESSION_TOKEN environment variable as detailed at [nextflow/issues/2839](https://github.com/nextflow-io/nextflow/issues/2839)

### Suggested Solution(s)
  * Set the AWS credentials up in your `nextflow.config` which will support the AWS_SESSION_TOKEN
```
aws {
    accessKey = 'XXXXXXXXXXXXXXXX'
    secretKey = 'XXXXXXXXXXXXXXXX'
    sessionToken = 'XXXXXXXXXXXXXXX'
} 
```

##  Container start errors
```
CannotStartContainerError: Error response from daemon: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: exec: "/usr/local/env-execute": stat /usr/local/env-execute: no such file or directory: un
```
### Possible Cause(s)
Nextflow on AWS Batch relies on the process containers being able to use a number of scripts that are mounted to the container. If references to these are wrong or do not exist then the tasks will not start.

### Suggested Solution(s)
 * If using the provided image setup with no changes, check the path specified for the aws-cli in your `nextflow.config` is set to
```
 aws.batch.cliPath = '/opt/aws-cli/bin/aws'
```

  * Check the target S3 bucket created in the set-up has the following path: `bucket-name/<namespace>-ecs-additions/SourceStag/ ` and that content is present. 
  * This location should contain a zip file that has the following in it:

```
.
├── awscli-shim.sh
├── ecs-additions-common.sh
├── ecs-additions-cromwell.sh
├── ecs-additions-nextflow.sh
├── ecs-additions-step-functions.sh
├── ecs-logs-collector.sh
├── fetch_and_run.sh
├── get-amazon-ebs-autoscale.sh
└── provision.sh
```
 * If this is missing check that `<namespace>-ecs-additions` exists and ran successfully in AWS Codepipeline and rerun if failures are present.
