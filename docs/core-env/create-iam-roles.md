# Core: Permissions

{{ deprecation_notice() }}

IAM is used to control access to your AWS resources.  This includes access by users and groups in your account, as well as access by AWS services such as AWS Batch operating on your behalf.

Services use IAM Roles which provide temporary access to AWS resources when needed.

!!! danger "IMPORTANT"
    You need to have Administrative access to your AWS account to make changes in IAM.

    A recommended way to do this is to create a user and add that user to a group with the `AdministratorAccess` managed policy attached.  This makes it easier to  revoke these privileges if necessary.

## Create IAM Resources

### IAM Policies

For the EC2 instance role described in the next section, it is recommended to restrict access to just the resources and permissions it needs to use.  In this case, it will be:

* Access to the specific buckets used for input and output data
* The ability to create and add EBS volumes to the instance (more on this later)

These policies could be used by other roles, so it will be easier to manage them if each are stand alone documents.

* **Bucket Access Policy (required)**:

This policy specifies full access to a single S3 bucket named `<bucket-name>` which physically resides in `<region>`.

```json
{
    "PolicyName": "s3bucket-access-<region>",
    "PolicyDocument": {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "s3:*",
                "Resource": [
                    "arn:aws:s3:::<bucket-name>",
                    "arn:aws:s3:::<bucket-name>/*"
                ]
            }
        ]
    }
}
```

If needed, the policy can be made more granular - i.e. only allowing access to a prefix within the bucket - by modifying the second `Resource` item to include the prefix path before the `*`.

* **EBS Autoscale Policy (required)**:

This policy allows job instance to attach EBS volumes to create extra scratch space for genomic data using [Amazon EBS Autoscale](https://github.com/awslabs/amazon-ebs-autoscale).

```json
{
    "PolicyName": "ebs-autoscale-<region>",
    "PolicyDocument": {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:AttachVolume",
                    "ec2:DescribeVolumeStatus",
                    "ec2:DescribeVolumes",
                    "ec2:ModifyInstanceAttribute",
                    "ec2:DescribeVolumeAttribute",
                    "ec2:CreateVolume",
                    "ec2:DeleteVolume",
                    "ec2:CreateTags"
                ],
                "Resource": "*"
            }
        ]
    }
}
```

### IAM Roles

IAM roles that your job execution environment in AWS Batch will use include:

* **Batch Service Role (required)**:
    
    Role used by AWS Batch to call other AWS services on its behalf.
    AWS Batch makes calls to other AWS services on your behalf to manage the resources that you use with the service. Before you can use the service, you must have an IAM policy and role that provides the necessary permissions to AWS Batch.
    [(Learn More)](https://docs.aws.amazon.com/batch/latest/userguide/service_IAM_role.html)

* **Batch Instance Profile (required)**:
    
    Role that defines service permissions for EC2 instances launched by AWS Batch.
    This role should also have attached policies (see above) that allow access to specific S3 buckets and the ability to modify storage (e.g. EBS volumes) on the instance.
    [(Learn More)](https://docs.aws.amazon.com/batch/latest/userguide/instance_IAM_role.html)

* **Batch SpotFleet Role (depends)**:
    
    This role is needed if you intend to launch spot instances from AWS Batch.
    If you create a managed compute environment that uses Amazon EC2 Spot Fleet Instances with a `BEST_FIT` allocation strategy, you must create a role that grants the Spot Fleet permission to set a cost threshold, launch, tag, and terminate instances on your behalf.
    [(Learn More)](https://docs.aws.amazon.com/batch/latest/userguide/spot_fleet_IAM_role.html)

* **Batch Job Role (optional)**:

    Role used to provide specific service permissions to individual jobs.
    Jobs can run without an IAM role. In that case, they inherit the
    permissions of the instance they run on.  Job roles are useful if you have jobs that utilize additional AWS resources such as buckets with supplementary data or need to interact with other AWS services like databases.

### Automated via CloudFormation

The CloudFormation template below creates all of the above roles and policies.

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | :--: |
{{ cfn_stack_row("Amazon IAM Roles", "GWFCore-IAM", "gwfcore/gwfcore-iam.template.yaml", "Create the necessary IAM Roles. This is useful to hand to someone with the right permissions to create these on your behalf. _You will need to provide a S3 bucket name_.", enable_cfn_button=False) }}

!!! info
    The launch button has been disabled above since this template is part of a set of nested templates. It is not recommended to launch it independently of its intended parent stack.

!!! danger "Administrative Access Required"
    In order run this CloudFormation template you you will need privileged access to your account either through an IAM user, STS assumed role, or CloudFormation Stack role.

### Manually via the AWS Console

#### Create a bucket access policy

* Go to the IAM Console
* Click on "Policies"
* Click on "Create Policy"
* Repeat the following for as many buckets as you will use (e.g. if you have one bucket for nextflow logs and another for nextflow workDir, you will need to do this twice)
  * Select "S3" as the service
  * Select "All Actions"
  * Under Resources select "Specific"
  * Under Resources > bucket, click "Add ARN"
    * Type in the name of the bucket
    * Click "Add"
  * Under Resources > object, click "Add ARN"
    * For "Bucket Name", type in the name of the bucket
    * For "Object Name", select "Any"
  * Click "Add additional permissions" if you have additional buckets you are using
* Click "Review Policy"
* Name the policy "bucket-access-policy"
* Click "Create Policy"

#### Create an EBS autoscale policy

* Go to the IAM Console
* Click on "Policies"
* Click on "Create Policy"
* Switch to the "JSON" tab
* Paste the following into the editor:

```json
{
    "Version": "2012-10-17",
    "Statement": {
        "Action": [
            "ec2:*Volume",
            "ec2:modifyInstanceAttribute",
            "ec2:describeVolumes"
        ],
        "Resource": "*",
        "Effect": "Allow"
    }
}
```

* Click "Review Policy"
* Name the policy "ebs-autoscale-policy"
* Click "Create Policy"

#### Create a Batch Service Role

This is a role used by AWS Batch to launch EC2 instances on your behalf.

* Go to the IAM Console
* Click on "Roles"
* Click on "Create role"
* Select "AWS service" as the trusted entity
* Choose "Batch" as the service to use the role
* Click "Next: Permissions"

In Attached permissions policies, the "AWSBatchServiceRole" will already be attached

* Click "Next: Tags".  (adding tags is optional)
* Click "Next: Review"
* Set the Role Name to "AWSBatchServiceRole"
* Click "Create role"

#### Create an EC2 Instance Role

This is a role that controls what AWS Resources EC2 instances launched by AWS Batch have access to.
In this case, you will limit S3 access to just the bucket you created earlier.

* Go to the IAM Console
* Click on "Roles"
* Click on "Create role"
* Select "AWS service" as the trusted entity
* Choose EC2 from the larger services list
* Choose "EC2 - Allows EC2 instances to call AWS services on your behalf" as the use case.
* Click "Next: Permissions"

* Type "ContainerService" in the search field for policies
* Click the checkbox next to "AmazonEC2ContainerServiceforEC2Role" to attach the policy

* Type "S3" in the search field for policies
* Click the checkbox next to "AmazonS3ReadOnlyAccess" to attach the policy

!!! note
    Enabling Read-Only access to all S3 resources is required if you use publicly available datasets such as the [1000 Genomes dataset](https://registry.opendata.aws/1000-genomes/), and others, available in the [AWS Registry of Open Datasets](https://registry.opendata.aws)

* Type "bucket-access-policy" in the search field for policies
* Click the checkbox next to "bucket-access-policy" to attach the policy

* Type "ebs-autoscale-policy" in the search field for policies
* Click the checkbox next to "ebs-autoscale-policy" to attach the policy

* Click "Next: Tags".  (adding tags is optional)
* Click "Next: Review"
* Set the Role Name to "ecsInstanceRole"
* Click "Create role"

#### Create an EC2 SpotFleet Role

This is a role that allows creation and launch of Spot fleets - Spot instances with similar compute capabilities (i.e. vCPUs and RAM).  This is for using Spot instances when running jobs in AWS Batch.

* Go to the IAM Console
* Click on "Roles"
* Click on "Create role"
* Select "AWS service" as the trusted entity
* Choose EC2 from the larger services list
* Choose "EC2 - Spot Fleet Tagging" as the use case

In Attached permissions policies, the "AmazonEC2SpotFleetTaggingRole" will already be attached

* Click "Next: Tags".  (adding tags is optional)
* Click "Next: Review"
* Set the Role Name to "AWSSpotFleetTaggingRole"
* Click "Create role"

#### Create a Job Role

This is a role used by individual Batch Jobs to specify permissions to AWS resources in addition to permissions allowed by the Instance Role above.

* Go to the IAM Console
* Click on "Roles"
* Click on "Create role"
* Select "AWS service" as the trusted entity
* Choose Elastic Container Service from the larger services list
* Choose "Elastic Container Service Task" as the use case.
* Click "Next: Permissions"

* Attach AWS managed and user defined policies as needed.

* Click "Next: Tags".  (adding tags is optional)
* Click "Next: Review"
* Set the Role Name to "BatchJobRole"
* Click "Create role"
