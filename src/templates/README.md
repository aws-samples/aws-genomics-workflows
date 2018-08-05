# Genomics on AWS CloudFormation templates

This directory contains example CloudFormation templates for setting up the resources for working with genomics and other large-scale biomedical research data.


root = to do
* inputs:
  - stack name root
  - az
  - tags
  - key pair name
  - s3 bucket name
* outputs:
  - job queue names
  - s3 bucket name


vpc = https://raw.githubusercontent.com/aws-quickstart/quickstart-aws-vpc/master/templates/aws-vpc.template
* inputs:
  * stack name
  * Availability Zones
  * tag for public & private subnets
  * key pair name
* outputs:
  - az
  - sg
  -
s3 = to do
* input:
  - stack name
  - s3 bucket name

iam = to do
* inputs:
  - stack name
  - s3 bucket name
* outputs
  - iam instance profile
  - iam ecs service role
  - iam ecs task roles
  - iam batch service role

batch =
* inputs:
  - stack name
  - azs
  - key pair name
  - iam instance profile
  - iam ecs role
  - iam ecs task roles
  - iam batch service role
  - iam batch spot fleet role
- outputs:
  - job Queue names
