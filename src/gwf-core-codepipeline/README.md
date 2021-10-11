# Genomics Workflow CodeBuild

This AWS CDK stack establishes an AWS CodePipeline that automatically keeps your account "GWF Core" infrastructure up to date with the
latest release of the [aws-samples/aws-genomics-workflows](https://github.com/aws-samples/aws-genomics-workflows) templates
and artifacts.

The pipeline is triggered by a GitHub webhook that is triggered by "Push" events on the "release" branch of the
aws-genomics-workflows repository. When triggered, it will clone the source code and build the templates and artifacts.
It will then delete any existing "GWF core" Cloudformation deployed stacks and replace them with a new stack. By using
a "delete and replace" strategy rather than an update we avoid issues where AWS Batch Compute Environments don't 
associate themselves with new versions of EC2 Launch Templates during an update.

The pipeline doesn't create any workflow engine stacks, such as Cromwell or Nextflow, on top of the core, although
it would be relatively easy to extend it for this purpose if required.

## PreRequisites

### GitHub OAuth token

To set up the GitHub hook and allow cloning of the aws-genomics-workflow repository you will need a GitHub OAuth
token with `Repo` and `admin:repo_hook` permissions. These should be stored in AWS Secrets Manager with the "secret name"
`github-token`.

* To create the token, follow [these instructions](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
* To store the token using the AWS CLI: `aws secretsmanager create-secret --name github-token
  --description "GitHub OAuth Token" --secret-string "insert your GitHub OAuth token"`

### CDK

To deploy this stack into your account you need to install AWS CDK >= version 1.127.0 which itself requires node.js 10.13.0 or later.

To install CDK type:

```shell
npm install -g aws-cdk
```

If you have not already done so your account and region need to be "bootstrapped" by CDK

```shell
cdk bootstrap aws://ACCOUNT-NUMBER/REGION
```

Full details can be found in the CDK [getting started guide](https://docs.aws.amazon.com/cdk/latest/guide/getting_started.html).

### AWS Account and Region

CDK will deploy the code pipeline infrastructure into the account and region determined by your curren AWS Profile.

## Deployment

To deploy the infrastructure into your account simply type:

```shell
cdk deploy
```

If you want to inspect the cloud formation template that will be used for the deployment you can print it to STDOUT with:

```shell
cdk synth
```

## Useful commands

 * `npm run build`   compile typescript to js
 * `npm run watch`   watch for changes and compile
 * `npm run test`    perform the jest unit tests
 * `cdk deploy`      deploy this stack to your default AWS account/region
 * `cdk diff`        compare deployed stack with current state
 * `cdk synth`       emits the synthesized CloudFormation template
