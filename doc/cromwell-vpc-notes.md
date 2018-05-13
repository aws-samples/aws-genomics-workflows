
# Notes on Amazon Virtual Private Cloud (VPC)

Amazon Virtual Private Cloud ([Amazon VPC](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Introduction.html)) enables you to launch AWS resources into a virtual network that you've defined. All users will need to designate a VPC to launch compute resources into.

While users are able to leverage a [default VPC and Subnets](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/default-vpc.html), we **strongly** recommend a more advanced setup that leverages private (not internet accessible) subnets and additional layers of security such as network Access Control Lists.

The [AWS Quickstart](https://aws.amazon.com/quickstart/) reference architecture for a [Modular and Scalable VPC Architecture](https://aws.amazon.com/quickstart/architecture/vpc/) serves this requirement. This Quick Start provides a networking foundation for AWS Cloud infrastructures. It deploys an Amazon Virtual Private Cloud (Amazon VPC) according to AWS best practices and guidelines.

The Amazon VPC reference architecture includes public and private subnets. The first set of private subnets share the default network access control list (ACL) from the Amazon VPC, and a second, optional set of private subnets include dedicated custom network ACLs per subnet. The Quick Start divides the Amazon VPC address space in a predictable manner across multiple Availability Zones, and deploys either NAT instances or NAT gateways, depending on the AWS Region you deploy the Quick Start in.

For architectural details, best practices, step-by-step instructions, and customization options, see the
[deployment guide](https://fwd.aws/9VdxN).

![Quick Start VPC Design Architecture](https://docs.aws.amazon.com/quickstart/latest/vpc/images/quickstart-vpc-design-fullscreen.png)

:bulb:  <span style="color: #FF6600;" >TIP</span>
<hr/>

You may also want to review the  [HIPAA on AWS Enterprise Accelerator](https://aws.amazon.com/quickstart/architecture/accelerator-hipaa/) for additional security best practices such as:

* Basic AWS Identity and Access Management (IAM) configuration with custom (IAM) policies, with associated groups, roles, and instance profiles
* Standard, external-facing Amazon Virtual Private Cloud (Amazon VPC) Multi-AZ architecture with separate subnets for different application tiers and private (back-end) subnets for application and database
* Amazon Simple Storage Service (Amazon S3) buckets for encrypted web content, logging, and backup data
* Standard Amazon VPC security groups for Amazon Elastic Compute Cloud (Amazon EC2) instances and load balancers used in the sample application stack
* A secured bastion login host to facilitate command-line Secure Shell (SSH) access to Amazon EC2 instances for troubleshooting and systems administration activities
* Logging, monitoring, and alerts using AWS CloudTrail, Amazon CloudWatch, and AWS Config rules
<hr/>
