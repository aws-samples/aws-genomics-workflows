import * as cdk from "@aws-cdk/core";
import * as batch from "@aws-cdk/aws-batch";
import * as ec2 from "@aws-cdk/aws-ec2";
import * as iam from "@aws-cdk/aws-iam";
import GenomicsComputeEnvironment from "./batch-compute-environmnet-construct";
import GenomicsLaunchTemplate from "./launch-template-construct";
import GenomicsJobQueue from "./job-queue-construct";
import GenomicsIam from "./batch-iam-stack";
import * as config from "../../app.config.json";


export interface GenomicsBatchStackProps {
  readonly stackProps: cdk.StackProps;
  readonly vpc: ec2.Vpc;
  readonly bucket: string;
};

export default class GenomicsBatchStack extends cdk.Stack {
  
  public readonly genomicsDefaultQueue: batch.JobQueue;
  public readonly genomicsHighPriorityQueue: batch.JobQueue;
  public readonly taskRole: iam.Role;

  constructor(scope: cdk.Construct, id: string, props: GenomicsBatchStackProps) {
    super(scope, id, props.stackProps);
    
    const env = props.stackProps.env as cdk.Environment;
    
    // Create IAM roles and policies for AWS Batch
    const genomicsIamProps = {
      bucketName: props.bucket,
      account: env.account as string
    }
    
    const genomicsIam = new GenomicsIam(this, `${config.projectName}-iam`, genomicsIamProps);
    this.taskRole = genomicsIam.taskRole;
    
    
    
    // Create a EC2 Launch Template to be used by AWS Batch
    const launchTemplateProps = {
      launchTemplateName: `${config.projectName}-launch-template`,
      volumeSize: config.batch.defaultVolumeSize
    };
    
    const launchTemplate = new GenomicsLaunchTemplate(this, launchTemplateProps.launchTemplateName, launchTemplateProps);
    
    
    // Create AWS Batch SPOT and On-Demand compute environments
    let envInstanceType = [];
    for (let i = 0; i < config.batch.instanceTypes.length; i++) {
      envInstanceType.push(new ec2.InstanceType(config.batch.instanceTypes[i]));
    }
    
    // Create spot compute environment for the genomics pipeline using SPOT instances
    const spotComputeEnvironmentProps = {
      computeEnvironmentName: `${config.projectName}-spot-compute-environment`,
      vpc: props.vpc,
      instanceTypes: envInstanceType,
      maxvCpus: config.batch.spotMaxVCPUs,
      instanceProfileArn: genomicsIam.instanceProfileArn,
      fleetRole: genomicsIam.fleetRole,
      serviceRole: genomicsIam.serviceRole,
      launchTemplateName: launchTemplate.template.launchTemplateName as string,
    };
    
    const spotComputeEnvironment = new GenomicsComputeEnvironment(this, 
      spotComputeEnvironmentProps.computeEnvironmentName, 
      spotComputeEnvironmentProps
    );
    
    // Create on demand compute environment using on demand instances
    const onDemandComputeEnvironmentProps = {
      computeEnvironmentName: `${config.projectName}-on-demand-compute-environment`,
      computeResourcesType: batch.ComputeResourceType.ON_DEMAND,
      allocationStrategy: batch.AllocationStrategy.BEST_FIT,
      vpc: props.vpc,
      instanceTypes: envInstanceType,
      maxvCpus: config.batch.onDemendMaxVCPUs,
      instanceProfileArn: genomicsIam.instanceProfileArn,
      fleetRole: genomicsIam.fleetRole,
      serviceRole: genomicsIam.serviceRole,
      launchTemplateName: launchTemplate.template.launchTemplateName as string,
    };
    
    const onDemandComputeEnvironment = new GenomicsComputeEnvironment(this, 
      onDemandComputeEnvironmentProps.computeEnvironmentName, 
      onDemandComputeEnvironmentProps
    );
      
      
    // Create default queue, using spot first and then on-demand instances
    const defaultQueueProps = {
      computeEnvironments: [
        spotComputeEnvironment.computeEnvironment
      ],
      jobQueueName: `${config.projectName}-default-queue`,
      priority: 100
    };
    
    const defaultQueue = new GenomicsJobQueue(this, defaultQueueProps.jobQueueName, defaultQueueProps);
    this.genomicsDefaultQueue = defaultQueue.jobQueue;
    
    
    // Create high priority queue, using on-demand instances and then spot
    const highPriorityQueueProps = {
      computeEnvironments: [
        onDemandComputeEnvironment.computeEnvironment,
        spotComputeEnvironment.computeEnvironment
        
      ],
      jobQueueName: `${config.projectName}-high-priority-queue`,
      priority: 1000
    }
    
    const highPriorityQueue = new GenomicsJobQueue(this, highPriorityQueueProps.jobQueueName, highPriorityQueueProps);
    this.genomicsHighPriorityQueue = highPriorityQueue.jobQueue;
    
    
  }
}
