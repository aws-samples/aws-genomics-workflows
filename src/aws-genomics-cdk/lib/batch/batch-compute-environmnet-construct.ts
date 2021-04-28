import * as cdk from "@aws-cdk/core";
import * as batch from "@aws-cdk/aws-batch";
import * as ec2 from "@aws-cdk/aws-ec2";
import * as ecs from "@aws-cdk/aws-ecs";
import * as iam from "@aws-cdk/aws-iam";
import * as config from "../../app.config.json";

export class GenomicsComputeEnvironmentProps {
  readonly computeResourcesType?: batch.ComputeResourceType;
  readonly vpc: ec2.Vpc;
  readonly allocationStrategy?: batch.AllocationStrategy;
  readonly computeResourcesTags?: { [key: string]: string };
  readonly instanceProfileArn: string;
  readonly fleetRole: iam.Role;
  readonly serviceRole: iam.Role;
  readonly instanceTypes: ec2.InstanceType[];
  readonly launchTemplateName: string;
  readonly maxvCpus: number;
  readonly computeEnvironmentName: string;
}

export default class GenomicsComputeEnvironment extends cdk.Construct {
  public readonly computeEnvironment: batch.ComputeEnvironment;

  constructor(
    scope: cdk.Construct,
    id: string,
    props: GenomicsComputeEnvironmentProps
  ) {
    super(scope, id);

    const computeResources = {
      type: props.computeResourcesType ?? batch.ComputeResourceType.SPOT,
      vpc: props.vpc,
      allocationStrategy:
        props.allocationStrategy ??
        batch.AllocationStrategy.SPOT_CAPACITY_OPTIMIZED,
      computeResourcesTags: props.computeResourcesTags ?? {
        Name: `${config.projectName}-instance`
      },
      image: ecs.EcsOptimizedImage.amazonLinux2(),
      instanceRole: props.instanceProfileArn,
      spotFleetRole: props.fleetRole,
      serviceRole: props.serviceRole,
      instanceTypes: props.instanceTypes,
      launchTemplate: {
        launchTemplateName: props.launchTemplateName,
      },
      maxvCpus: props.maxvCpus,
    };

    const computeEnvironmentProps = {
      computeEnvironmentName: props.computeEnvironmentName,
      enabled: true,
      managed: true,
      serviceRole: props.serviceRole,
      computeResources: computeResources,
    };

    this.computeEnvironment = new batch.ComputeEnvironment(
      this,
      computeEnvironmentProps.computeEnvironmentName,
      computeEnvironmentProps
    );
  }
}
