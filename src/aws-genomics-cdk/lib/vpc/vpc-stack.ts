import * as cdk from "@aws-cdk/core";
import * as ec2 from "@aws-cdk/aws-ec2";
import * as config from "../../app.config.json";

export default class GenomicsVpcStack extends cdk.Stack {
  public readonly vpc: ec2.Vpc;

  constructor(scope: cdk.Construct, id: string, props: cdk.StackProps) {
    super(scope, id, props);

    const subnetConf = [
      {
        cidrMask: config.VPC.cidrMask,
        name: "private",
        subnetType: ec2.SubnetType.PRIVATE,
      },
      {
        cidrMask: config.VPC.cidrMask,
        name: "public",
        subnetType: ec2.SubnetType.PUBLIC,
      }
    ];

    const vpcProp = {
      cidr: config.VPC.cidr,
      maxAZs: config.VPC.maxAZs,
      subnetConfiguration: subnetConf
    };

    this.vpc = new ec2.Vpc(this, config.VPC.VPCName, vpcProp);
  }
}
