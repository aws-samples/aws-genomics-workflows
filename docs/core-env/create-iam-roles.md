# Creating IAM Roles

Below are IAM roles that your job execution environment in AWS Batch will use:

* Batch Service Role:
    
    (required)
    Role used by AWS Batch to call other AWS services on its behalf.
    AWS Batch makes calls to other AWS services on your behalf to manage the resources that you use with the service. Before you can use the service, you must have an IAM policy and role that provides the necessary permissions to AWS Batch.
    [(Learn More)](https://docs.aws.amazon.com/batch/latest/userguide/service_IAM_role.html)

* Batch Instance Profile:
    
    (required)
    Role that defines service permissions for EC2 instances launched by AWS Batch.
    For example, this is used to allow access to specific S3 buckets.
    [(Learn More)](https://docs.aws.amazon.com/batch/latest/userguide/instance_IAM_role.html)

* Batch SpotFleet Role:
    
    (depends)
    This is role is needed if you intend to launch spot instances from AWS Batch.
    If you create a managed compute environment that uses Amazon EC2 Spot Fleet Instances, you must create a role that grants the Spot Fleet permission to bid on, launch, tag, and terminate instances on your behalf.
    [(Learn More)](https://docs.aws.amazon.com/batch/latest/userguide/spot_fleet_IAM_role.html)

* Batch Job Role:

    (optional)
    Role used to provide service permissions to individual jobs.
    Jobs can run without an IAM role. In that case, they inherit the
    permissions of the instance they run on.

The CloudFormation template below creates all of the above roles.

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | :--: |
{{ cfn_stack_row("Amazon IAM Roles", "GenomicsWorkflow-IAM", "aws-genomics-iam.template.yaml", "Create the necessary IAM Roles. This is useful to hand to someone with the right permissions to create these on your behalf. _You will need to provide a S3 bucket name_.") }}

!!! note
    In order to create these roles you will need privileged access to your account.
