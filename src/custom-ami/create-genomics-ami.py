#!/usr/bin/env python
from __future__ import print_function
import os, sys, stat
import time
import json
import boto3
import argparse
from textwrap import dedent

def _dedent(string):
    return dedent(string).strip()

##### Parameters ###########
def str2bool(v):
    if v.lower() in ('yes', 'true', 't', 'y', '1'):
        return True
    elif v.lower() in ('no', 'false', 'f', 'n', '0'):
        return False
    else:
        raise argparse.ArgumentTypeError('Boolean value expected.')

parser = argparse.ArgumentParser(description="Custom AMI for genomics bootstrap script")
parser.add_argument("--profile", type=str, default=None)
parser.add_argument("--scratch-mount-point", type=str, default="/scratch")
parser.add_argument("--key-pair-name", type=str, default="genomics-ami")
parser.add_argument("--vpc-id", type=str)
parser.add_argument("--subnet-id", type=str)
parser.add_argument("--security-group-id", type=str)
parser.add_argument("--terminate-instance", dest='terminate_instance', action='store_true', help="Do not terminate the instance after minting a new AMI")
parser.add_argument("--no-terminate-instance", dest='terminate_instance', action='store_false', help="Do not terminate the instance after minting a new AMI")
parser.set_defaults(terminate_instance=True)

args = parser.parse_args()

session = boto3.Session(profile_name=args.profile)
ec2 = session.resource('ec2')

print('Using profile: {}'.format(session.profile_name))

########## VPC and Subnet ##################

vpc_id = None
subnet_id = None
vpc = None
subnet = None

if args.vpc_id and args.subnet_id:
    vpc_id = args.vpc_id
    subnet_id = args.subnet_id
else:
    vpc = None
    for i in ec2.vpcs.filter(Filters=[{"Name": "isDefault","Values": ['true']}]):
        vpc = i
    if not vpc:
        print("No default VPC found. You must provide *both* VPC and Subnet IDs that are able to access public IP domains on CLI")
        parser.print_usage()
        exit()
    else:
        vpc_id = vpc.id
        subnet = [x for x in vpc.subnets.all()][0]
        subnet_id = subnet.id

########## EC2 Instance ################

## Security Group
security_group_id = args.security_group_id
if security_group_id is not None:
    print("Getting the security group from ID ", security_group_id)
    security_group = ec2.SecurityGroup(security_group_id)
    security_group.reload()
else:
    sg_name = "GenomicsAmiSG-" + subnet_id
    print("Getting the security group from name", sg_name)
    security_group=None
    try:
        security_groups = [x for x in ec2.security_groups.filter(Filters=[{'Name': 'group-name', "Values": [sg_name]}])]
        security_group = security_groups[0]
    except IndexError as e:
        print("Security Group {0} does not exist. Creating.".format(sg_name))
        security_group = ec2.create_security_group(
            Description='A security group for creating the custom AMI',
            GroupName=sg_name,
            VpcId=vpc_id
        )
        security_group.authorize_ingress(
            FromPort=22,
            ToPort=22,
            IpProtocol="tcp",
            CidrIp="0.0.0.0/0"
        )
    security_group.reload()
    security_group_id = security_group.id
## Key Pair
key_pair_name=args.key_pair_name
kp_fname = "{0}.pem".format(key_pair_name)
key_pair = ec2.KeyPair(key_pair_name)
try:
    key_pair.reload()
    print("Key Pair [", key_pair_name,"] exists.")
except Exception as e:
    print("Key Pair {0} does not exist. Creating.".format(key_pair_name))
    key_pair = ec2.create_key_pair(KeyName=key_pair_name)
    pem = open(kp_fname,'w')
    pem.write(key_pair.key_material)
    print(kp_fname)
    pem.close()
    # os.lchmod(kp_fname, 0600)
    os.lchmod(kp_fname, stat.S_IRUSR | stat.S_IWUSR)
    print("Key Pair PEM file written to ", kp_fname)

# IAM Role
# need to add the following policy to the instance created to avoid ecs-agent errors
# arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role

print('Creating IAM role and instance profile: ', end='')
iam = session.client('iam')

TIMESTAMP = time.strftime('%Y%m%dT%H%M%S')
IAM_PREFIX = 'GenomicsAMICreation'
IAM_ROLE_NAME = IAM_PREFIX + 'Role_' + TIMESTAMP
IAM_INSTANCE_PROFILE_NAME = IAM_PREFIX + 'Instance_' + TIMESTAMP
iam.create_role(
    RoleName=IAM_ROLE_NAME,
    Description='Role used to create a custom AMI for genomics workloads',
    AssumeRolePolicyDocument=_dedent(
        """
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": "sts:AssumeRole",
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "ec2.amazonaws.com"
                    }
                }
            ]
        }
        """
    )
)
iam.attach_role_policy(
    RoleName=IAM_ROLE_NAME,
    PolicyArn='arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role'
)
iam.create_instance_profile(
    InstanceProfileName=IAM_INSTANCE_PROFILE_NAME
)
iam.add_role_to_instance_profile(
    InstanceProfileName=IAM_INSTANCE_PROFILE_NAME,
    RoleName=IAM_ROLE_NAME
)

instance_profile = iam.get_instance_profile(
    InstanceProfileName=IAM_INSTANCE_PROFILE_NAME
    )['InstanceProfile']

print(
    '[ROLE]: {role}; [INSTANCE PROFILE]: {instance_profile}'.format(
        role=IAM_ROLE_NAME, instance_profile=IAM_INSTANCE_PROFILE_NAME
    )
)

## cleanup procedures
# iam.remove_role_from_instance_profile(
#     InstanceProfileName=IAM_INSTANCE_PROFILE_NAME,
#     RoleName=IAM_ROLE_NAME
# )
# iam.delete_instance_profile(
#     InstanceProfileName=IAM_INSTANCE_PROFILE_NAME
# )

## ECS-Optimized AMI
# You can find the latest available on this page of our documentation:
# http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html
# (note the AMI identifier is region specific)
print("Launching a new EC2 instance.")
region  = session.region_name

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


ecs_ami_id = region2ami[region]
ecs_image = ec2.Image(ecs_ami_id)

# Create a new BlockDeviceMappings block to encrypt the docker and scratch drives
block_device_mappings = ecs_image.block_device_mappings
# remove the Encrypted attribute from root volume
block_device_mappings[0]['Ebs'].pop("Encrypted",None)
# change docker volume to be encrypted
block_device_mappings[1]['Ebs']["Encrypted"] = True
# add new new 20GB encrypted volume for scratch
block_device_mappings.append({
    'DeviceName': '/dev/sdc',
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
  - wget

runcmd:
  - pip install -U awscli boto3
  - cd /opt && wget https://aws-genomics-workflows.s3.amazonaws.com/aws-batch-genomics.tar.gz && tar -xzf aws-batch-genomics.tar.gz
  - sh /opt/aws-batch-genomics/src/custom-ami/ebs-autoscale/bin/init-ebs-autoscale.sh  {0} /dev/sdc  2>&1 > /var/log/init-ebs-autoscale.log
  - cd /opt && wget https://aws-genomics-workflows.s3.amazonaws.com/aws-cromwell-containers.tgz && tar -xzf aws-cromwell-containers.tgz
  - cd /opt/containers/ecs-proxy && sh ./build-proxy
  - docker pull elerch/amazon-ecs-agent:latest && docker tag amazon/amazon-ecs-agent:latest amazon/amazon-ecs-agent:1.19.1 && docker tag elerch/amazon-ecs-agent:latest amazon/amazon-ecs-agent:latest && docker kill ecs-agent && sleep 10
'''.format(args.scratch_mount_point)

ri_args = dict(
    ImageId=ecs_ami_id,
    BlockDeviceMappings=block_device_mappings,
    MaxCount=1,MinCount=1,
    KeyName=key_pair_name,
    InstanceType="t2.micro",
    NetworkInterfaces=[{
        "DeviceIndex": 0,
        "AssociatePublicIpAddress": True,
        "Groups": [security_group_id],
        "DeleteOnTermination": True,
        "SubnetId": subnet_id
    }],
    UserData=user_data
)

instances = ec2.create_instances(**ri_args)
instance = instances[0]
print("Waiting on instance to have a IP...", end="")
sys.stdout.flush()
instance.wait_until_running()
instance.reload()
instance_ip = instance.public_ip_address
instance_id = instance.id
print("[", instance_ip,"].")

client = session.client("ec2")

status =  client.describe_instance_status(InstanceIds=[instance_id])
print("Waiting on instance to pass health checks.", end="")
while len(status["InstanceStatuses"]) == 0 or not status["InstanceStatuses"][0]["InstanceStatus"]["Status"] == "ok":
    print(".",end="")
    sys.stdout.flush()
    time.sleep(5)
    status =  client.describe_instance_status(InstanceIds=[instance_id])


print("Associating instance profile.")
client.associate_iam_instance_profile(
    IamInstanceProfile={'Arn': instance_profile['Arn']},
    InstanceId=instance_id
)


## New AMI creation
print("instance available and healthy.\nMinting a new AMI...", end="")
sys.stdout.flush()
time.sleep(30)
instance.reload()
image = instance.create_image(
    Name="genomics-ami-{0}".format(time.strftime('%Y%m%d-%H%M%S')),
    Description="A custom AMI for use with AWS Batch with genomics workflows"
)
while image.state != "available":
    print(".",end="")
    sys.stdout.flush()
    time.sleep(5)
    image.reload()
image_id = image.image_id
print("new AMI [{0}] created.".format(image_id))

if args.terminate_instance:
    print("Terminating instance...",end="")
    sys.stdout.flush()
    instance.reload()
    instance.terminate()
    instance.wait_until_terminated()
    instance.reload()
    print("terminated.")

report =_dedent(
    """
    Resources that were created on your behalf:

        * IAM Instance Profile: {instance_profile_name}
        * IAM Role: {role_name}

        * EC2 Key Pair: {key_pair_name}
        * EC2 Security Group: {security_group_id}
        * EC2 Instance ID: {instance_id}
        * EC2 AMI ImageId: {image_id}

    Take note the returned EC2 AMI ImageId. We will use that for the AWS Batch setup.
    """
)

report_d = dict(
    instance_profile_name=IAM_INSTANCE_PROFILE_NAME,
    role_name=IAM_ROLE_NAME,
    key_pair_name=args.key_pair_name,
    security_group_id=security_group_id,
    image_id=image_id,
    instance_id=instance_id,
    instance_ip=instance_ip,
    kp_fname=kp_fname
)

print(report.format(**report_d))

if not args.terminate_instance:
    if args.profile:
        report_d['profile_name'] = '--profile ' + args.profile
    else:
        report_d['profile_name'] = ''
    
    print(_dedent(
        """
        If you want to poke around the system, you can log into it via SSH:

            ssh -i {kp_fname} ec2-user@{instance_ip}
        
        After you are done, you can terminate the instance with the AWS Web console or the AWS CLI

            aws {profile_name} ec2 terminate-instances --instance-ids {instance_id}
        """
        ).format(**report_d)
    )