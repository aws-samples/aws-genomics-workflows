#!/usr/bin/env python
from __future__ import print_function
import os, sys
import time
import json
import boto3
import argparse

parser = argparse.ArgumentParser(description="Custom AMI bootstrap script")
parser.add_argument("--key-pair-name", type=str, default="custom-ami")
parser.add_argument("--vpc-id", type=str)
parser.add_argument("--subnet-id", type=str)
args = parser.parse_args()

########## VPC and Subnet ##################
vpc = boto3.client("ec2")
vpc_id = None
subnet_id = None
# Check for a default VPC
if args.vpc_id and args.subnet_id:
    vpc_id = args.vpc_id
    subnet_id = args.subnet_id
else:
    response = vpc.describe_vpcs(Filters=[{"Name": "isDefault","Values": ['true']}])
    if len(response["Vpcs"]) == 1:
        vpc_id = response["Vpcs"][0]["VpcId"]
        response = vpc.describe_subnets(Filters=[
            {"Name":"vpc-id","Values": [vpc_id]},
            {"Name": "defaultForAz", "Values": ["true"]}])
        subnet_id = response["Subnets"][0]["SubnetId"]
    else:
        print("No default VPC found. You must provide *both* VPC and Subnet IDs that are able to access public IP domains on CLI")
        parser.print_usage()
        exit()

####### IAM section ##########
# Create managed policy
iam = boto3.client("iam")
policy_doc = '''{
"Version": "2012-10-17",
"Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "ec2:DetachVolume",
            "ec2:AttachVolume",
            "ec2:DeleteVolume",
            "ec2:ModifyVolume",
            "ec2:ModifyVolumeAttribute",
            "ec2:DescribeVolumeStatus",
            "ec2:DescribeVolumes",
            "ec2:DescribeVolumeAttribute",
            "ec2:CreateVolume"
        ],
        "Resource": "*"
    }
]
}'''
try:
    ebs_admin_policy  = iam.create_policy(
        PolicyName="CustomAmiEbsAdmin",
        PolicyDocument=policy_doc
    )
    ebs_admin_policy_arn = ebs_admin_policy["Policy"]["Arn"]
except Exception as e:
    print(e)
    arn = iam.get_user()["User"]["Arn"].split(":")[0:5]
    arn.append("policy/CustomAmiEbsAdmin")
    ebs_admin_policy_arn = ":".join(arn)

# Create role
assume_policy_doc ='''{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Principal": {
            "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
        }
    ]
}'''
try:
    ebs_admin_role = iam.create_role(
        RoleName="CustomAmiEbsAdminRole",
        AssumeRolePolicyDocument=assume_policy_doc,
    )
except Exception as e:
    print(e)
    ebs_admin_role = iam.get_role(RoleName="CustomAmiEbsAdminRole")

iam.attach_role_policy(
    RoleName="CustomAmiEbsAdminRole",
    PolicyArn=ebs_admin_policy_arn
)

try:
    instance_profile = iam.create_instance_profile(
        InstanceProfileName="CustomAmiEbsAdminProfile"
    )
except Exception as e:
    print(e)
    instance_profile = iam.get_instance_profile(
        InstanceProfileName="CustomAmiEbsAdminProfile"
    )

try:
    iam.add_role_to_instance_profile(
        InstanceProfileName="CustomAmiEbsAdminProfile",
        RoleName="CustomAmiEbsAdminRole"
    )
except Exception as e:
    print(e)
    pass


########## EC2 Instance ################
ec2 = boto3.client("ec2")

## Security Group
sg_name = "CustomAmiCustomAmi-" + subnet_id
try:
    ec2.create_security_group(
        GroupName=sg_name,
        Description="Custom AMI SG",
        VpcId=vpc_id
    )
except Exception as e:
    print(e)
    pass

sg = ec2.describe_security_groups(Filters=[
    {"Name":"group-name", "Values": [sg_name]},
    {"Name":"vpc-id", "Values":[vpc_id]}
])

security_group_id = sg["SecurityGroups"][0]["GroupId"]

try:
    ec2.authorize_security_group_ingress(
        CidrIp="0.0.0.0/0",
        FromPort=22,
        ToPort=22,
        IpProtocol='tcp',
        GroupId=security_group_id
    )
except Exception as e:
    print(e)
    pass

## ECS AMI
# These are the latest ECS optimized AMIs as of Feb 2018:
#
#   amzn-ami-2017.09.h-amazon-ecs-optimized
#   ECS agent:    1.17.1
#   Docker:       17.09.1-ce
#   ecs-init:     1.17.1-1
#
# You can find the latest available on this page of our documentation:
# http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html
# (note the AMI identifier is region specific)

region  = boto3.Session().region_name

region2ami  = {
    "us-east-2": "ami-b86a5ddd",
    "us-east-1": "ami-a7a242da",
    "us-west-2": "ami-92e06fea",
    "us-west-1": "ami-9ad4dcfa",
    "eu-west-3": "ami-698b3d14",
    "eu-west-2": "ami-f4e20693",
    "eu-west-1": "ami-0693ed7f",
    "eu-central-1": "ami-0799fa68",
    "ap-northeast-2": "ami-a5dd70cb",
    "ap-northeast-1": "ami-68ef940e",
    "ap-southeast-2": "ami-ee884f8c",
    "ap-southeast-1": "ami-0a622c76",
    "ca-central-1": "ami-5ac94e3e",
    "ap-south-1": "ami-2e461a41",
    "sa-east-1": "ami-d44008b8"
}
ecs_ami = region2ami[region]
try:
    r = ec2.create_key_pair(KeyName=args.key_pair_name)
    kpfname = "{0}.pem".format(args.key_pair_name)
    pem = open(kpfname,"w")
    pem.write(r["KeyMaterial"])
    pem.close()
    os.lchmod(kpfname,0600)
except Exception as e:
    pass

response = ec2.describe_images(ImageIds=[ecs_ami])

block_device_mappings = response['Images'][0]["BlockDeviceMappings"]
block_device_mappings[0]['Ebs'].pop("Encrypted",None)
block_device_mappings[1]['Ebs']["Encrypted"] = True
user_data = '''#cloud-config
repo_update: true
repo_upgrade: all

packages:
 - jq
 - aws-cli
 - e2e2fsprogs
 - lvm2
 - sed

runcmd:
 - curl -o /tmp/custom-ami-bootstrap.sh https://cromwell-aws-batch.s3.amazonaws.com/files/custom-ami-bootstrap.sh
 - sh /tmp/custom-ami-bootstrap.sh docker_scratch docker_scratch_pool /scratch > /var/log/custom-ami-bootstrap.log
'''

instance_profile = iam.get_instance_profile(InstanceProfileName="CustomAmiEbsAdminProfile")
ip_arn = instance_profile["InstanceProfile"]["Arn"]
ri_args = dict(
    ImageId=ecs_ami,
    BlockDeviceMappings=block_device_mappings,
    MaxCount=1,MinCount=1,
    KeyName=args.key_pair_name,
    InstanceType="t2.large",
    IamInstanceProfile={"Arn": ip_arn},
    NetworkInterfaces=[{
        "DeviceIndex": 0,
        "AssociatePublicIpAddress": True,
        "Groups": [security_group_id],
        "DeleteOnTermination": True,
        "SubnetId": subnet_id
    }],
    UserData=user_data
)

response = ec2.run_instances(**ri_args)
instance_id = response["Instances"][0]["InstanceId"]
time.sleep(5)
instance =  ec2.describe_instances(InstanceIds=[instance_id])
while not  instance["Reservations"][0]["Instances"][0]['NetworkInterfaces'][0].has_key('Association'):
    print("Waiting on instance to have a IP.")
    time.sleep(5)
    instance =  ec2.describe_instances(InstanceIds=[instance_id])
instance_ip = instance["Reservations"][0]["Instances"][0]['NetworkInterfaces'][0]['Association']['PublicIp']

status =  ec2.describe_instance_status(InstanceIds=[instance_id])
print("Waiting on instance to pass health checks.", end="")
while len(status["InstanceStatuses"]) == 0 or not status["InstanceStatuses"][0]["InstanceStatus"]["Status"] == "ok":
    print(".",end="")
    sys.stdout.flush()
    time.sleep(5)
    status =  ec2.describe_instance_status(InstanceIds=[instance_id])



report ='''
Resources that were created on your behalf:

    * IAM Policy:   {iam_policy}
    * IAM Role:     {iam_role}
    * EC2 Instance Profile: {instance_profile}
    * EC2 Key Pair: {key_pair_name}
    * EC2 Security Group: {security_group_id}
    * EC2 Instance ID: {instanc_id}

To finish off the image, issue the following commands:

Execute the following commands in a terminal window:

ssh -i {key_pair_name}.pem ec2-user@{instance_ip}
sudo stop ecs
sudo stop ebs-autoscale
sudo rm -f /var/lib/ecs/data/ecs_agent_data.json /var/log/ebs-autoscale.log
exit
aws ec2 create-image \\
  --instance-id {instanc_id} \\
  --name "cromwell-aws-$(date '+%Y%m%d-%H%M%S')" \\
  --description "A custom AMI for use with AWS Batch"


Take note the returned ImageId. We will use that for the AWS Batch setup.

'''
report_d = dict(
    iam_policy=ebs_admin_policy_arn,
    iam_role=ebs_admin_role["Role"]["Arn"],
    instance_profile=instance_profile["InstanceProfile"]["Arn"],
    key_pair_name=args.key_pair_name,
    security_group_id=security_group_id,
    instanc_id=instance_id,
    instance_ip=instance_ip
)

print(report.format(**report_d))
