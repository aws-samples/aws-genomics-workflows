# Amazon Elastic Block Store Autoscale

This is an example of a small daemon process that monitors a BTRFS filesystem mountpoint and automatically expands it when free space falls below a configured threshold. New [Amazon EBS](https://aws.amazon.com/ebs/) volumes are added to the instance as necessary and the underlying [BTRFS filesystem](http://btrfs.wiki.kernel.org) expands while still mounted. As new devices are added, the BTRFS metadata blocks are rebalanced to mitigate the risk that space for metadata will not run out.

## Assumptions:

1. That this code is running on a AWS EC2 instance
2. The instance has a IAM Instance Profile with appropriate permissions to create and attache new EBS volumes. Ssee the [IAM Instance Profile](#iam_instance_profile) section below for more details
3. That prerequisites are installed on the instance.

Provided in this repo are:

1. A python [script](bin/create-ebs-volume.py) that creates and attaches new EBS volumes to the current instance
2. The daemon [script](bin/ebs-autoscale) that monitors disk space and expands the BTRFS filesystem by leveraging the above script to add EBS volumes, expand the filesystem, and rebalance the metadata blocks
2. A template for an [upstart configuration file](templates/ebs-autoscale.conf.template)
2. A [logrotate configuration file](templates/ebs-autoscale.logrotate) which should not be needed but may as well be in place for long-running instances.
5. A [initialization script](bin/init-ebs-autoscale.sh) to configure and install all of the above
6. A [cloud-init](templates/cloud-init-userdata.yaml) file for user-data that installs required packages and runs the initialization script. By default this creates a mount point of `/scratch` on a encrypted 20GB EBS volume. To change the mount point, edit the file.

## Installation

The easiest way to set up an instance is to provide a launch call with the userdata [cloud-init script](templates/cloud-init-userdata.yaml). Here is an example of launching the [Amazon ECS-Optimized  AMI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html) in us-east-1 using this file:

```bash
aws ec2 run-instances --image-id ami-5253c32d \
  --key-name MyKeyPair \
  --user-data file://./templates/cloud-init-userdata.yaml \
  --count 1 \
  --security-group-ids sg-123abc123 \
  --instance-type t2.micro \
  --iam-instance-profile Name=MyInstanceProfileWithProperPermissions
```


## A note on IAM Instance Profile

In the above, we assume that the `MyInstanceProfileWithProperPermissions` EC2 Instance Profile exists and has the following permissions:

```json
{
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
                "ec2:DeleteVolume"
            ],
            "Resource": "*"
        }
    ]
}
```
