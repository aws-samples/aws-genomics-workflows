## Step 4. Creating a VPC for Cromwell

While you can use an existing VPC to implement a Cromwell deployment, this tutorial assumes that you have a clean environment and VPC with public and private subnets. We recommend the use of the AWS Quickstart reference deployment for a [Modular and Scalable VPC Architecture](https://aws.amazon.com/quickstart/architecture/vpc/). This Quick Start provides a networking foundation for AWS Cloud infrastructures. It deploys an Amazon Virtual Private Cloud (Amazon VPC) according to AWS best practices and guidelines.

The Amazon VPC reference architecture includes public and private subnets. The first set of private subnets share the default network access control list (ACL) from the Amazon VPC, and a second, optional set of private subnets include dedicated custom network ACLs per subnet. The Quick Start divides the Amazon VPC address space in a predictable manner across multiple Availability Zones, and deploys either NAT instances or NAT gateways, depending on the AWS Region you deploy the Quick Start in.

For architectural details, best practices, step-by-step instructions, and customization options, see the
[deployment guide](https://fwd.aws/9VdxN).

Click on the "Launch Quick Start" link, confirm that you are in your preferred AWS Region, and click "Next"

![CloudFormation console confirm proper AWS Region](../images/prereq-vpc-1.png)

Next, fill in a custom name for the CloudFormation stack, in this example we use "Cromwell-VPC". We also select a set of VPC Availability Zones and adjust the number to match the amount we picked (up to four).

![CloudFormation stackname ](../images/prereq-vpc-2-name-subnets.png)

Scroll down to the bottom of the form and choose the EC2 Key Pair Name that you created in [Step 3](#step-3).

![CloudFormation Key Pair](../images/prereq-vpc-3-key-pair.png)

Click through the rest of the wizard, the defaults are fine. Once the CloudFormation Stack creation completes, head on over to the [VPC Web console](https://console.aws.amazon.com/vpc/home?) to make note of the subnet IDs and security group for the Cromwell VPC. While we are there, we will adjust the default security group to accept SSH connections.

![CloudFormation VPC Security Group 1](../images/prereq-vpc-4-sg-1.png)
![CloudFormation VPC Security Group 2](../images/prereq-vpc-5-sg-2.png)
![CloudFormation VPC Subnets](../images/prereq-vpc-6-subnets.png)

Make a note of how to get these values for later.

<table>
<tr><th>
:bulb:  <span style="color: orange;" >TIP</span>
</th><td>

You may also want to review the  <a href="https://aws.amazon.com/quickstart/architecture/accelerator-hipaa/" > HIPAA on AWS Enterprise Accelerator </a>
for additional security best practices such as:
<ul>
<li> Basic AWS Identity and Access Management (IAM) configuration with custom (IAM) policies, with associated groups, roles, and instance profiles</li>
<li> Standard, external-facing Amazon Virtual Private Cloud (Amazon VPC) Multi-AZ architecture with separate subnets for different application tiers and private (back-end) subnets for application and database</li>
<li> Amazon Simple Storage Service (Amazon S3) buckets for encrypted web content, logging, and backup data</li>
<li> Standard Amazon VPC security groups for Amazon Elastic Compute Cloud (Amazon EC2) instances and load balancers used in the sample application stack</li>
<li> A secured bastion login host to facilitate command-line Secure Shell (SSH) access to Amazon EC2 instances for troubleshooting and systems administration activities</li>
<li> Logging, monitoring, and alerts using AWS CloudTrail, Amazon CloudWatch, and AWS Config rules</li>
</ul>
</td></tr>
</table>
