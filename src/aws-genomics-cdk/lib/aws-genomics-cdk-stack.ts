import * as cdk from "@aws-cdk/core";
import * as ec2 from "@aws-cdk/aws-ec2";
import * as s3 from "@aws-cdk/aws-s3";
import * as config from "../app.config.json";
import GenomicsVpcStack from "./vpc/vpc-stack";
import GenomicsBatchStack from "./batch/batch-stack";

//Workflows
import { WorkflowConfig } from "./workflows/workflow-config";
import VariantCallingStateMachine from "./workflows/variant-calling-stack";

export class AwsGenomicsCdkStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props: cdk.StackProps) {
    super(scope, id, props);

    // Create a new VPC or use an existing one
    let vpc: ec2.Vpc;
    if (config.VPC.createVPC) {
      vpc = new GenomicsVpcStack(this, config.VPC.VPCName, props).vpc;
    } else {
      vpc = ec2.Vpc.fromLookup(this, `${config.projectName}-vpc-lookup`, {
        vpcName: config.VPC.VPCName,
      }) as ec2.Vpc;
    }

    // Create a new bucket if set in the config
    if (!config.S3.existingBucket) {
      const bucketProps = {
        bucketName: config.S3.bucketName,
        encryption: s3.BucketEncryption.S3_MANAGED,
        removalPolicy: cdk.RemovalPolicy.RETAIN,
      };

      new s3.Bucket(this, bucketProps.bucketName, bucketProps);
    }

    // Create an AWS Batch resources
    const batchProps = {
      stackProps: props,
      vpc: vpc,
      bucket: config.S3.bucketName,
    };

    const batch = new GenomicsBatchStack(
      this,
      `${config.projectName}-batch`,
      batchProps
    );

    // loop throgh the app.config workflows file and set infrastructure for
    // the provided workflows
    let workflow: WorkflowConfig;
    for (let i = 0; i < config.workflows.length; i++) {
      workflow = config.workflows[i] as WorkflowConfig;

      switch (workflow.name) {
        case "variantCalling":
          new VariantCallingStateMachine(
            this,
            `${config.projectName}-${workflow.name}`,
            {
              stackProps: props,
              batchQueue:
                workflow.spot === true
                  ? batch.genomicsDefaultQueue
                  : batch.genomicsHighPriorityQueue,
              taskRole: batch.taskRole,
            }
          );
          break;
      }
    }
  }
}
