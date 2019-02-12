#!/usr/bin/env python
"""
This script creates a custom AMI based on the ECS optimized AMI
"""

# Copyright 2018 Amazon.com, Inc. or its affiliates.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#
#  1. Redistributions of source code must retain the above copyright notice,
#  this list of conditions and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright
#  notice, this list of conditions and the following disclaimer in the
#  documentation and/or other materials provided with the distribution.
#
#  3. Neither the name of the copyright holder nor the names of its
#  contributors may be used to endorse or promote products derived from
#  this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
#  BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
#  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
#  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
#  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
#  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
#  IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.


from __future__ import print_function
import os, sys, stat
import time
import json
import argparse
from textwrap import dedent

import boto3
from botocore.exceptions import ClientError

TIMESTAMP = time.strftime('%Y%m%d-%H%M%S')
DEFAULT_USER_DATA_FILE = './default-genomics-ami.cloud-init.yaml'

def _dedent(string):
    """utility function for long strings"""
    return dedent(string).strip()

parser = argparse.ArgumentParser(
    description="Creates a custom AMI for genomics workloads")

parser.add_argument(
    "--profile", 
    type=str, 
    default=None,
    help="""
        AWS profile to use instead of \"default\". Create one using the AWS 
        CLI e.g. aws configure --profile <profile>
    """
)

parser.add_argument(
    "--region",
    dest="region_name",
    type=str,
    help="""
        AWS region name to use when creating resources.  
        If not specified, uses the configured default region for the current 
        profile.  See: \"aws configure\".
    """
)

parser.add_argument(
    "--scratch-mount-point", 
    type=str, 
    default="/scratch",
    help="Path for the scratch mount point in the instance (default: %(default)s)")

parser.add_argument(
    "--key-pair-name", type=str, default="genomics-ami")

parser.add_argument(
    "--user-data",
    dest="user_data_file",
    type=str,
    default=DEFAULT_USER_DATA_FILE,
    help="""
        Cloud Init spec file (yaml format) for provisioning the instance on 
        first boot.  (default: %(default)s)
    """
)

parser.add_argument(
    "--src-ami-id",
    type=str,
    help="""
        AMI ID to start the instance with and customize.  Note this must be 
        available in the region you launch your instance in.  If unspecified, 
        will default to the latest region specific version of the ECS Optimized AMI.
    """
)

parser.add_argument(
    "--vpc-id", 
    type=str,
    help='EC2 instance VPC ID')

parser.add_argument(
    "--subnet-id", 
    type=str,
    help="EC2 instance subnet ID")

parser.add_argument(
    "--security-group-id", 
    type=str,
    help="EC2 instance security group ID")

parser.add_argument(
    "--use-instance-profile",
    action="store_true",
    help="""
        Use an IAM instance profile to create the AMI.  Note: this requires
        privileges to create IAM roles.
    """
)

parser.add_argument(
    "--instance-profile-name",
    type=str,
    help="IAM instance profile name to associate with the instance"
)

parser.add_argument(
    "--max-instance-creation-attempts",
    type=int,
    default=10,
    help="""
        Maximum number of times to attempt to create the instance.
        (default: %(default)d)
    """
)

encryption_group = parser.add_mutually_exclusive_group()

encryption_group.add_argument(
    "--ebs-encryption",
    dest="ebs_encryption",
    action='store_true',
    help="Encrypt attached EBS volumes and snapshots (default)"
)

encryption_group.add_argument(
    "--no-ebs-encryption",
    dest="ebs_encryption",
    action='store_false',
    help="Do not encrypt attached EBS volumes and snapshots"
)

parser.add_argument(
    "--no-health-checks",
    dest="check_health",
    action="store_false",
    help="Do not wait for instance health checks to complete"
)

parser.add_argument(
    "--no-ami",
    dest='create_ami',
    action='store_false',
    help="Do not create an AMI, used for testing purposes"
)

parser.add_argument(
    "--ami-name",
    default="genomics-ami",
    help="""
        Name for the AMI.  A timestamp will be appended to this name.
        (default: %(default)s)
    """
)

parser.add_argument(
    "--ami-description",
    default="A custom AMI for use with AWS Batch with genomics workflows",
    help="""
        Description for the AMI.
        (default: \"%(default)s\") 
    """
)

parser.add_argument(
    "--iam-cleanup",
    action="store_true",
    help="""
        Remove role and instance profile when done.  Only valid if no
        --instance-profile-name is provided and --terminate-instance is set.
    """
)

termination_group = parser.add_mutually_exclusive_group()

termination_group.add_argument(
    "--terminate-instance", 
    dest='terminate_instance', 
    action='store_true', 
    help="Terminate the instance when complete (default)")

termination_group.add_argument(
    "--no-terminate-instance", 
    dest='terminate_instance', 
    action='store_false', 
    help="Do not terminate the instance when complete")

parser.set_defaults(
    use_instance_profile=False,
    ebs_encryption=True,
    terminate_instance=True,
    check_health=True,
    create_ami=True,
    iam_cleanup=False
)

args = parser.parse_args()

session = boto3.Session(profile_name=args.profile, region_name=args.region_name)
ssm = session.client('ssm')
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
    print("Getting security group named:", sg_name)
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
    
    with open(kp_fname, 'w') as pem:
        pem.write(key_pair.key_material)
    
    os.chmod(kp_fname, stat.S_IRUSR | stat.S_IWUSR)
    print("Key Pair PEM file written to ", kp_fname)


if not args.use_instance_profile:
    instance_profile = None
    IAM_INSTANCE_PROFILE_NAME = None

else:
    # IAM Role
    # need to add the following policy to the instance created to avoid ecs-agent errors
    # arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role
    iam = session.client('iam')

    if args.instance_profile_name:
        IAM_INSTANCE_PROFILE_NAME = args.instance_profile_name

    else:
        IAM_PREFIX = 'GenomicsAMICreation'
        IAM_ROLE_NAME = IAM_PREFIX + 'Role_' + TIMESTAMP
        IAM_INSTANCE_PROFILE_NAME = IAM_ROLE_NAME
        
        print(
            'Creating IAM role and instance profile: {instance_profile} '.format(
                instance_profile=IAM_INSTANCE_PROFILE_NAME
            ),
            end='')
        
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
        print('.', end='')
        iam.attach_role_policy(
            RoleName=IAM_ROLE_NAME,
            PolicyArn='arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role'
        )
        print('.', end='')
        iam.create_instance_profile(
            InstanceProfileName=IAM_INSTANCE_PROFILE_NAME
        )
        print('.', end='')
        iam.add_role_to_instance_profile(
            InstanceProfileName=IAM_INSTANCE_PROFILE_NAME,
            RoleName=IAM_ROLE_NAME
        )
        print('.', end='')
        print(' done')


    instance_profile = iam.get_instance_profile(
        InstanceProfileName=IAM_INSTANCE_PROFILE_NAME
        )['InstanceProfile']

if args.src_ami_id:
    ecs_ami_id = args.src_ami_id

else:
    # Retrieve the region specific ECS-Optimized AMI using the SSM API
    # to ensure that the most current AMI is used
    ecs_ami_id = ssm.get_parameter(
        Name='/aws/service/ecs/optimized-ami/amazon-linux/recommended/image_id')['Parameter']['Value']

ecs_image = ec2.Image(ecs_ami_id)
print("Source AMI ID:", ecs_ami_id)

# Create a new BlockDeviceMappings block to encrypt the docker and scratch drives
block_device_mappings = ecs_image.block_device_mappings

# remove the Encrypted attribute from root volume
block_device_mappings[0]['Ebs'].pop("Encrypted",None)

# set docker volume encryption
block_device_mappings[1]['Ebs']["Encrypted"] = args.ebs_encryption

# add 20GB volume for scratch
block_device_mappings.append({
    'DeviceName': '/dev/sdc',
    'Ebs': {
        'Encrypted': args.ebs_encryption,
        'DeleteOnTermination': True,
        'VolumeSize': 20,
        'VolumeType': 'gp2'
    }
})

print('Using user-data file: ', args.user_data_file)
with open(args.user_data_file, 'r') as f:
    user_data = f.read().format(scratch_mount_point=args.scratch_mount_point)

MAX_CREATION_ATTEMPTS = args.max_instance_creation_attempts
creation_attempts = 0
print('Creating EC2 instance ', end='')
instances = None
while not instances and creation_attempts < MAX_CREATION_ATTEMPTS:
    print('.', end='')
    try:
        iam_instance_profile = {}
        if instance_profile:
            iam_instance_profile = {'Arn': instance_profile['Arn']}
        
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
            IamInstanceProfile=iam_instance_profile,
            UserData=user_data
        )

        instances = ec2.create_instances(**ri_args)
    except ClientError as err:
        pass
    
    creation_attempts += 1
    
    sys.stdout.flush()
    time.sleep(5)

if creation_attempts >= MAX_CREATION_ATTEMPTS:
    raise RuntimeError(
        'Maximum creation instance creation attempts ({max_creation_attempts}) reached'.format(
            max_creation_attempts=MAX_CREATION_ATTEMPTS
        )
    )

print(' done')
    

instance = instances[0]
print("Getting EC2 instance IP ... ", end="")
sys.stdout.flush()
instance.wait_until_running()
instance.reload()
instance_ip = instance.public_ip_address
instance_id = instance.id
print("[", instance_ip, "]")

client = session.client("ec2")

if args.check_health:
    status =  client.describe_instance_status(InstanceIds=[instance_id])
    print("Checking EC2 Instance health ", end="")
    while len(status["InstanceStatuses"]) == 0 or not status["InstanceStatuses"][0]["InstanceStatus"]["Status"] == "ok":
        print(".",end="")
        sys.stdout.flush()
        time.sleep(5)
        status =  client.describe_instance_status(InstanceIds=[instance_id])

    print(" available and healthy")


image_id = None
image_name = None
image_desc = None
if args.create_ami:
    ## New AMI creation
    print("Creating AMI ", end="")
    sys.stdout.flush()
    time.sleep(30) # why wait this long?
    instance.reload()
    
    image_name = "{ami_name}-{timestamp}".format(
        ami_name=args.ami_name,
        timestamp=TIMESTAMP)
    image_desc = args.ami_description

    image = instance.create_image(
        Name=image_name,
        Description=image_desc
    )

    while image.state != "available":
        print(".",end="")
        sys.stdout.flush()
        time.sleep(5)
        image.reload()
    image_id = image.image_id
    print("new AMI [{0}] created.".format(image_id))

if args.terminate_instance:
    print("Terminating instance ...",end="")
    sys.stdout.flush()
    instance.reload()
    instance.terminate()
    instance.wait_until_terminated()
    instance.reload()
    print("terminated.")

    if args.iam_cleanup and args.use_instance_profile:
        if not args.instance_profile_name:
            iam.remove_role_from_instance_profile(
                InstanceProfileName=IAM_INSTANCE_PROFILE_NAME,
                RoleName=IAM_ROLE_NAME
            )
            iam.delete_instance_profile(
                InstanceProfileName=IAM_INSTANCE_PROFILE_NAME
            )


report =_dedent(
    """
    Resources that were created on your behalf:

        * AWS Region: {region_name}

        * IAM Instance Profile: {instance_profile_name}

        * EC2 Key Pair: {key_pair_name}
        * EC2 Security Group: {security_group_id}
        * EC2 Instance ID: {instance_id}
        * EC2 AMI ImageId: {image_id}
            * name: {image_name}
            * description: {image_desc}
    
    """
)

report_d = dict(
    region_name=session.region_name,
    instance_profile_name=IAM_INSTANCE_PROFILE_NAME,
    key_pair_name=args.key_pair_name,
    security_group_id=security_group_id,
    image_id=image_id,
    image_name=image_name,
    image_desc=image_desc,
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