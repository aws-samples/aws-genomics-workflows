# Notes on VPC design for Genomics Workflows

While you can use an existing VPC to implement a Cromwell deployment, we strongly recommend utilizing a VPC with private subnets for the AWS Batch instances. Doing so will effectively restrict access to the instances from the internet, and help meet security and compliance requirements, such as [dbGaP](http://j.mp/aws-dbgap).

We recommend the use of the AWS Quickstart reference deployment for a [Modular and Scalable VPC Architecture](https://aws.amazon.com/quickstart/architecture/vpc/). This Quick Start provides a networking foundation for AWS Cloud infrastructures. It deploys an Amazon Virtual Private Cloud (Amazon VPC) according to AWS best practices and guidelines.

The Amazon VPC reference architecture includes public and private subnets. The first set of private subnets share the default network access control list (ACL) from the Amazon VPC, and a second, optional set of private subnets include dedicated custom network ACLs per subnet. The Quick Start divides the Amazon VPC address space in a predictable manner across multiple Availability Zones, and deploys either NAT instances or NAT gateways, depending on the AWS Region you deploy the Quick Start in.

For architectural details, best practices, step-by-step instructions, and customization options, see the
[deployment guide](https://fwd.aws/9VdxN).

Click on the "Launch Quick Start" link, confirm that you are in your preferred AWS Region, and click "Next"

![CloudFormation console confirm proper AWS Region](./images/prereq-vpc-1.png)

Next, fill in a custom name for the CloudFormation stack, in this example we use "Cromwell-VPC". We also select a set of VPC Availability Zones and adjust the number to match the amount we picked (up to four).

TODO: Update below to take out specific "Cromwell" name from VPC
![CloudFormation stackname ](./images/prereq-vpc-2-name-subnets.png)

Scroll down to the bottom of the form and choose an existing EC2 Key Pair Name. If you don't see one, you may need to [create one](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair) and reload the page.

![CloudFormation Key Pair](./images/prereq-vpc-3-key-pair.png)

Click through the rest of the wizard, the defaults are fine. Once the CloudFormation Stack creation completes, head on over to the [VPC Web console](https://console.aws.amazon.com/vpc/home?) to make note of the subnet IDs and security group for the Cromwell VPC.

TODO: Update below to take out specific "Cromwell" name from VPC
![CloudFormation VPC Subnets](./images/prereq-vpc-6-subnets.png)

TODO: Consider deleting this section, not greate security advice.  
While you are there, you should create a new security group that accepts SSH connections.

TODO: Update below to take out specific "Cromwell" name from VPC
![CloudFormation VPC Security Group 1](./images/prereq-vpc-4-sg-1.png)
![CloudFormation VPC Security Group 2](./images/prereq-vpc-5-sg-2.png)

!!! tip
    You may also want to review the [HIPAA on AWS Enterprise Accelerator](https://aws.amazon.com/quickstart/architecture/accelerator-hipaa/) for additional security best practices such as:

    *  Basic AWS Identity and Access Management (IAM) configuration with custom (IAM) policies, with associated groups, roles, and instance profiles
    *  Standard, external-facing Amazon Virtual Private Cloud (Amazon VPC) Multi-AZ architecture with separate subnets for different application tiers and private (back-end) subnets for application and database
    *  Amazon Simple Storage Service (Amazon S3) buckets for encrypted web content, logging, and backup data
    *  Standard Amazon VPC security groups for Amazon Elastic Compute Cloud (Amazon EC2) instances and load balancers used in the sample application stack
    *  A secured bastion login host to facilitate command-line Secure Shell (SSH) access to Amazon EC2 instances for troubleshooting and systems administration activities
    *  Logging, monitoring, and alerts using AWS CloudTrail, Amazon CloudWatch, and AWS Config rules
