# Building Custom Resources

This section describes how to build and upload templates and artifacts to use in a customized deployment.  Once uploaded, the locations of the templates and artifacts are used when deploying the Nextflow on AWS Batch solution (see [Customized Deployment](custom-deploy.md))

## Building a Custom Distribution

This step involves building a distribution of templates and artifacts from the solution's source code.

First, create a local clone of the [Genomics Workflows on AWS](https://github.com/aws-samples/aws-genomics-workflows) source code.  The code base contains several directories:

* `_scripts/`: Shell scripts for building and uploading the customized distribution of templates and artifacts
* `docs/`: Source code for the documentation, written in [MarkDown](https://markdownguide.org) for the [MkDocs](https://mkdocs.org) publishing platform.  This documentation may be modified, expanded, and contributed in the same way as source code.
* `src/`: Source code for the components of the solution:
    * `containers/`: CodeBuild buildspec files for building AWS-specific container images and pushing them to ECR
        * `_common/`
            * `build.sh`: A generic build script that first builds a base image for a container, then builds an AWS specific image
            * `entrypoint.aws.sh`: A generic entrypoint script that wraps a call to a binary tool in the container with handlers data staging from/to S3
        * `nextflow/`
            * `Dockerfile`
            * `nextflow.aws.sh`: Docker entrypoint script to execute the Nextflow workflow on AWS Batch
    * `ebs-autoscale/`
        * `get-amazon-ebs-autoscale.sh`: Script to retrieve and install [Amazon EBS Autoscale](https://github.com/awslabs/amazon-ebs-autoscale)
    * `ecs-additions/`: Scripts to be installed on ECS host instances to support the distribution
        * `awscli-shim.sh`: Installed as `/opt/aws-cli/bin/aws` and mounted onto the container, allows container images without full glibc to use the AWS CLI v2 through supplied shared libraries (especially libz) and `LD_LIBRARY_PATH`.
        * `ecs-additions-common.sh`: Utility script to install `fetch_and_run.sh`, Nextflow and Cromwell shims, and swap space
        * `ecs-additions-cromwell-linux2-worker.sh`: 
        * `ecs-additions-cromwell.sh`: 
        * `ecs-additions-nextflow.sh`: 
        * `ecs-additions-step-functions.sh`: 
        * `fetch_and_run.sh`: Uses AWS CLI to download and run scripts and zip files from S3
        * `provision.sh`: Appended to the userdata in the launch template created by [gwfcore-launch-template](custom-deploy.md): Starts SSM Agent, ECS Agent, Docker; runs `get-amazon-ebs-autoscale.sh`, `ecs-additions-common.sh` and orchestrator-specific `ecs-additions-` scripts.
    * `lambda/`: Lambda functions to create, modify or delete ECR registries or CodeBuild jobs
    * `templates/`: CloudFormation templates for the solution stack, as described in [Customized Deployment](custom-deploy.md)

## Deploying a Custom Distribution

The script `_scripts/deploy.sh` will create a custom distribution of artifacts and templates from files in the source tree, then upload this distribution to an S3 bucket.  It will optionally also build and deploy a static documentation site from the Markdown documentation files. Its usage is:

```sh
    deploy.sh [--site-bucket BUCKET] [--asset-bucket BUCKET] 
              [--asset-profile PROFILE] [--deploy-region REGION] 
              [--public] [--verbose] 
              STAGE

    --site-bucket BUCKET        Deploy documentation site to BUCKET
    --asset-bucket BUCKET       Deploy assets to BUCKET
    --asset-profile PROFILE     Use PROFILE for AWS CLI commands
    --deploy-region REGION      Deploy in region REGION
    --public                    Deploy to public bucket with '--acl public-read' (Default false)
    --verbose                   Display more output
    STAGE                       'test' or 'production'
```

When running this script from the command line, use the value `test` for the stage.  This will deploy the templates and artifacts into a directory `test` in your deployment bucket:

```
$ aws s3 ls s3://my-deployment-bucket/test/
    PRE artifacts/
    PRE templates/
```

Use these values when deploying a customized installation, as described in [Customized Deployment](custom-deploy.md), sections 'Artifacts and Nested Stacks' and 'Nextflow'.  In the example from above, the values to use would be:

* Artifact S3 Bucket Name: `my-deployment-bucket`
* Artifact S3 Prefix: `test/artifacts`
* Template Root URL: `https://my-deployment-bucket.s3.amazonaws.com/test/templates`

The use of `production` for stage is reserved for deployments from a Travis CI/CD environment; this usage will deploy into a subdirectory named after the current release tag.