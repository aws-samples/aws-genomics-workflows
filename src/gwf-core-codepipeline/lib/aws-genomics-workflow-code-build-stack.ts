import * as cdk from '@aws-cdk/core';
import * as codebuild from '@aws-cdk/aws-codebuild';
import * as s3 from '@aws-cdk/aws-s3';
import * as iam from '@aws-cdk/aws-iam';
import * as codepipeline from '@aws-cdk/aws-codepipeline';
import * as actions from '@aws-cdk/aws-codepipeline-actions';
import * as ec2 from '@aws-cdk/aws-ec2';
import * as regionInfo from '@aws-cdk/region-info';


export class AwsGenomicsWorkflowCodeBuildStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const info = regionInfo.RegionInfo.get(this.region);
    const s3Endpoint = info.servicePrincipal("s3.amazonaws.com");

    const vpc = new ec2.Vpc(this, "CromwellVPC", {
      maxAzs: 3,
      gatewayEndpoints: {
        S3: {
          service: ec2.GatewayVpcEndpointAwsService.S3,
        },
      }
    });

    // S3 bucket for storing templates and artifacts
    const artifactBucket = new s3.Bucket(this,"GWFArtifactsBucket", {
      encryption: s3.BucketEncryption.S3_MANAGED,
    });

    // S3 bucket that Cromwell will use
    const gwfBucket = new s3.Bucket(this, "GWFCoreBucket", {
      encryption: s3.BucketEncryption.S3_MANAGED,
    })

    // objects needed for the "Source" stage of the pipeline
    const gitHubToken: cdk.SecretValue = cdk.SecretValue.secretsManager("github-token")
    const sourceOutput = new codepipeline.Artifact();
    const sourceAction = new actions.GitHubSourceAction({
      actionName: "GitHub_Source",
      owner: 'aws-samples',
      repo: "aws-genomics-workflows",
      branch: "release",
      oauthToken: gitHubToken,
      output: sourceOutput,
      trigger: actions.GitHubTrigger.WEBHOOK
    })

    // objects needed for the "Build" stage of the pipeline
    const buildOutput = new codepipeline.Artifact();
    const project = new codebuild.Project(this, "GenomicsWorkflowBuildProject", {
      description: "Builds the templates and artifacts for aws-genomics-workflows",
      artifacts: codebuild.Artifacts.s3({
        bucket: artifactBucket,
        packageZip: false,
      }),
      buildSpec: codebuild.BuildSpec.fromObject({
        version: 0.2,
        phases: {
          build: {
            commands: [
              "ls -alF",
              "bash _scripts/make-dist.sh --verbose",
              "ls -alF dist/",
              `aws s3 sync dist/ s3://${artifactBucket.bucketName}`
            ],
          },
        },
        artifacts: {
          "base-directory": "dist",
          files: "**/*",
        }
      }),
      environment: {buildImage: codebuild.LinuxBuildImage.AMAZON_LINUX_2_3},
      concurrentBuildLimit: 1,
      timeout: cdk.Duration.minutes(15),
    });
    project.addToRolePolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ["s3:Get*", "s3:Put*", "s3:List*"],
      resources: [`${artifactBucket.bucketArn}`, `${artifactBucket.bucketArn}/*`]
    }));
    const buildAction = new actions.CodeBuildAction({
      actionName: "Build_Artifacts_And_Templates",
      project: project,
      input: sourceOutput,
      outputs: [ buildOutput ]
    });

    //objects needed for the "Deploy" stage of the pipeline
    const deleteGWFCoreStackAction = new actions.CloudFormationDeleteStackAction({
      actionName: "Delete_GWF_Core_Stack",
      stackName: "GWFCoreStack",
      adminPermissions: true,
      runOrder: 10,
    });
    const createGWFCoreAction = new actions.CloudFormationCreateUpdateStackAction({
      actionName: "Create_GWF_Core",
      stackName: "GWFCoreStack",
      adminPermissions: true,
      templatePath: buildOutput.atPath("templates/gwfcore/gwfcore-root.template.yaml"),
      parameterOverrides: {
        VpcId: vpc.vpcId,
        SubnetIds: vpc.privateSubnets.map(value => value.subnetId).join(","),
        ArtifactBucketName: artifactBucket.bucketName,
        TemplateRootUrl: `https://${artifactBucket.bucketName}.${s3Endpoint}/templates`,
        S3BucketName: gwfBucket.bucketName,
        ExistingBucket: "Yes",
      },
      runOrder: 20,
    });


    // the pipeline
    new codepipeline.Pipeline(this, 'AmazonGenomicsWorkflowPipeline', {
      pipelineName: 'AmazonGenomicsWorkflowPipeline',
      stages: [
        {
          stageName: 'Source',
          actions: [
            sourceAction,
          ],
        },
        {
          stageName: 'Build',
          actions: [
            buildAction
          ],
        },
        {
          stageName: 'Deploy',
          actions: [
              deleteGWFCoreStackAction,
              createGWFCoreAction,
          ],
        },
      ],
    });

  }
}
