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

## ECS-Optimized AMI
# You can find the latest available on this page of our documentation:
# http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html
# (note the AMI identifier is region specific)

region  = boto3.Session().region_name

region2ami  = {
    "us-east-2": "ami-956e52f0",
    "us-east-1": "ami-5253c32d",
    "us-west-2": "ami-d2f489aa",
    "us-west-1": "ami-6b81980b",
    "eu-west-3": "ami-ca75c4b7",
    "eu-west-2": "ami-3622cf51",
    "eu-west-1": "ami-c91624b0",
    "eu-central-1": "ami-10e6c8fb",
    "ap-northeast-2": "ami-7c69c112",
    "ap-northeast-1": "ami-f3f8098c",
    "ap-southeast-2": "ami-bc04d5de",
    "ap-southeast-1": "ami-b75a6acb",
    "ca-central-1": "ami-da6cecbe",
    "ap-south-1": "ami-c7072aa8",
    "sa-east-1": "ami-a1e2becd"
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

# Create a new BlockDeviceMappings block to encrypt the docker and scratch drives
block_device_mappings = response['Images'][0]["BlockDeviceMappings"]
# remove the Encrypted attribute from root volume
block_device_mappings[0]['Ebs'].pop("Encrypted",None)
# change docker volume to be encrypted
block_device_mappings[1]['Ebs']["Encrypted"] = True
# add new new 20GB encrypted volume for scratch
block_device_mappings.append({
    'DeviceName': '/dev/xvdc',
    'Ebs': {
        'Encrypted': True,
        'DeleteOnTermination': True,
        'VolumeSize': 20,
        'VolumeType': 'gp2'
    }
})

user_data = '''#cloud-config
repo_update: true
repo_upgrade: all

packages:
  - jq
  - btrfs-progs
  - python27-pip
  - sed

runcmd:
  - pip install -U awscli boto3
  - curl -o /tmp/custom-ami-bootstrap.sh http://cromwell-aws-batch.s3.amazonaws.com/files/custom-ami-bootstrap.sh
  - sh /tmp/custom-ami-bootstrap.sh /scratch /dev/xvdc  2>&1 > /var/log/custom-ami-bootstrap.log
'''

ri_args = dict(
    ImageId=ecs_ami,
    BlockDeviceMappings=block_device_mappings,
    MaxCount=1,MinCount=1,
    KeyName=args.key_pair_name,
    InstanceType="t2.large",
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
