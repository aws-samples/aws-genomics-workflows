import * as cdk from "@aws-cdk/core";
import * as iam from "@aws-cdk/aws-iam";
import * as path from "path";
import * as fs from "fs";
import * as config from "../../app.config.json";

export interface GenomicsIamProps {
    readonly bucketName: string;
    readonly account: string;
}

export default class GenomicsIam extends cdk.Stack {
    public readonly serviceRole: iam.Role;
    public readonly taskRole: iam.Role;
    public readonly instanceProfileArn: string;
    public readonly fleetRole: iam.Role;
    
    constructor(scope: cdk.Construct, id: string, props: GenomicsIamProps) {
    super(scope, id);
        
        // Create a task role to be used by AWS batch container
        const taskRoleProps = {
            roleName: `${config.projectName}-ecs-task-role`,
            assumedBy: new iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
            description: "allow ecs task to assume a role for the genomics pipleine",
            managedPolicies: [iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonS3ReadOnlyAccess")]
        };
        
        this.taskRole = new iam.Role(this, taskRoleProps.roleName, taskRoleProps);
        
        
        // Create an instance role for the EC2 host machine for AWS Batch
        const instanceRoleProps = {
            roleName: `${config.projectName}-batch-instance-role`,
            assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com"),
            description: "allow ec2 instance to assume a role for the genomics pipleine",
            managedPolicies: [
                iam.ManagedPolicy.fromAwsManagedPolicyName("service-role/AmazonEC2ContainerServiceforEC2Role"),
                iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonS3ReadOnlyAccess"),
                iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore")
            ]
        };
        
        const instanceRole = new iam.Role(this, instanceRoleProps.roleName, instanceRoleProps);
        
        
        // Create a spot fleet role to be used by AWS Batch when launching spot instances
        const fleetRoleProps = {
            roleName: `${config.projectName}-spot-fleet-role`,
            assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com"),
            description: "allow ec2 instance to assume a role for the genomics pipleine",
            managedPolicies: [iam.ManagedPolicy.fromAwsManagedPolicyName("service-role/AmazonEC2SpotFleetTaggingRole")]
        };
        
        this.fleetRole = new iam.Role(this, fleetRoleProps.roleName, fleetRoleProps);
        
        
        // Create a service role for AWS Batch so it can assume other roles for the genomics pipeline
        const batchServiceRoleProps = {
            roleName: `${config.projectName}-batch-service-role`,
            assumedBy: new iam.ServicePrincipal("batch.amazonaws.com"),
            description: "allow batch to assume a role for the genomics pipleine",
            managedPolicies: [iam.ManagedPolicy.fromAwsManagedPolicyName("service-role/AWSBatchServiceRole")]
        };
        
        this.serviceRole = new iam.Role(this, batchServiceRoleProps.roleName, batchServiceRoleProps);
        
        
        // Create a policy to allow read and writes for an S3 bucket and add it to the task and instance roles
        const filePath = path.join(__dirname, "../../assets/genomics-policy-s3.json");
        const bucketPolicy = fs.readFileSync(filePath, {encoding: "utf-8"}).replace(/BUCKET_NAME/g, props.bucketName);
        
        const policyProps = {
            policyName: `${config.projectName}-policy-s3`,
            document: iam.PolicyDocument.fromJson(JSON.parse(bucketPolicy)),
            force: true,
            roles: [this.taskRole, instanceRole]
        }
        const policy = new iam.Policy(this, policyProps.policyName, policyProps);
        
        
        // Create an instance profile to be used by AWS Batch compute environment
        const instanceProfileProps = {
          roles: [instanceRoleProps.roleName],
          instanceProfileName: `${config.projectName}-batch-instance-profile`
        };
        const instanceProfile = new iam.CfnInstanceProfile(this, instanceProfileProps.instanceProfileName, instanceProfileProps);
        this.instanceProfileArn = `arn:aws:iam::${props.account}:instance-profile/${instanceProfileProps.instanceProfileName}`;
    }
}