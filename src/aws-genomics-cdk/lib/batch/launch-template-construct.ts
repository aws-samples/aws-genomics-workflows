import * as cdk from "@aws-cdk/core";
import * as ec2 from "@aws-cdk/aws-ec2";
import * as path from "path";
import * as fs from "fs";


export interface GenomicsLaunchTemplateProps {
  readonly launchTemplateName: string;
  readonly volumeSize: number;
  readonly volumeType?: string;
  readonly encrypted?: boolean;
  readonly userData?: string;
}

export default class GenomicsLaunchTemplate extends cdk.Construct {
  public readonly template: ec2.CfnLaunchTemplate;

  constructor(
    scope: cdk.Construct,
    id: string,
    props: GenomicsLaunchTemplateProps
  ) {
    super(scope, id);

    let userData;

    if (props.userData !== undefined) {
      userData = props.userData;
    } else {
      const filePath = path.join(
        __dirname,
        "../../assets/launch_template_user_data.txt"
      );
      userData = fs.readFileSync(filePath).toString("base64");
    }

    const launchTemplateProps = {
      launchTemplateName: props.launchTemplateName,
      launchTemplateData: {
        blockDeviceMappings: [
          {
            deviceName: "/dev/xvda",
            ebs: {
              encrypted: props.encrypted ?? true,
              volumeSize: props.volumeSize,
              volumeType: props.volumeType ?? "gp2",
            },
          },
        ],
        userData: userData,
      },
    };

    this.template = new ec2.CfnLaunchTemplate(
      this,
      props.launchTemplateName,
      launchTemplateProps
    );
  }
}
