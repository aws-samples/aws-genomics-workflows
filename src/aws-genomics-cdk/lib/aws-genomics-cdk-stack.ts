import * as cdk from "@aws-cdk/core";
import * as ec2 from "@aws-cdk/aws-ec2";
import * as s3 from "@aws-cdk/aws-s3";
import * as config from "../app.config.json";
import GenomicsVpcStack from "./vpc/vpc-stack";
import GenomicsBatchStack from "./batch/batch-stack";
import GenomicsStateMachineProps from "./step-functions/genomics-state-machine-stack";

export class AwsGenomicsCdkStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props: cdk.StackProps) {
    super(scope, id, props);

    // Create a new VPC or use an existing one
    let vpc: ec2.Vpc;
    if (config.VPC.createVPC) {
      vpc = new GenomicsVpcStack(this, "genomics-vpc", props).vpc;
    } else {
      vpc = ec2.Vpc.fromLookup(this, "genomics-vpc-lookup", {
        vpcName: config.VPC.existingVPCName,
      }) as ec2.Vpc
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

    const batch = new GenomicsBatchStack(this, "genomics-batch", batchProps);
    
    if(config.stepFunctions.launchDemoPipeline === true){
      const genomicsDemoProps = {
        genomicsDefaultQueue: batch.genomicsDefaultQueue,
        genomicsHighPriorityQueue: batch.genomicsHighPriorityQueue,
        env: props.env as cdk.ResourceEnvironment,
        taskRole: batch.taskRole
      };
      
      new GenomicsStateMachineProps(this, "genomics-demo-pipeline", genomicsDemoProps)
    }
  }
}
