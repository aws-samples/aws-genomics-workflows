import * as cdk from "@aws-cdk/core";
import * as batch from "@aws-cdk/aws-batch";
import * as ecs from "@aws-cdk/aws-ecs";

import {GenomicsJobDefinitionProps} from "./job-definitions";

export default class GenomicsJobDefinition extends cdk.Construct{
    
    public readonly jobDefinition: batch.JobDefinition;
    
    constructor(scope: cdk.Construct, id: string, props: GenomicsJobDefinitionProps) {
        super(scope, id);
    
        const repositoryUri = `${props.env.account}.dkr.ecr.${props.env.region}.amazonaws.com/${props.repository}`;
        const containerImage = ecs.ContainerImage.fromRegistry(repositoryUri);
        
        const mountPoints = [
            {
                containerPath: "/opt/aws-cli",
                readOnly: false,
                sourceVolume: "awscli"
            },
            {
                containerPath: "/data",
                readOnly: false,
                sourceVolume: "data"
            }
        ];
        
        const volumes = [
            {
                name: "awscli",
                host: { sourcePath: "/opt/aws-cli" }
            },
            {
                name: "data",
                host: { sourcePath: "/data" }
            }
        ];
        
        const jobDefinitionContainerProps = {
            image: containerImage,
            jobRole: props.jobRole,
            memoryLimitMiB: props.memoryLimit,
            mountPoints: mountPoints,
            volumes: volumes,
            vcpus: props.vcpus ?? 1
        };
        
        const jobDefinitionProps = {
          container: jobDefinitionContainerProps,
          jobDefinitionName: id,
          retryAttempts: props.retryAttempts ?? 1,
          timeout: cdk.Duration.seconds(props.timeout ?? 3600)
        };
        
        this.jobDefinition = new batch.JobDefinition(this, id, jobDefinitionProps);
    }
}