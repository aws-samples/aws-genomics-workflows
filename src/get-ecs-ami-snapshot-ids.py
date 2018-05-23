import boto3
import yaml

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
    "sa-east-1": "ami-d44008b8"}
result ={"AWSRegionToAMI": {} }
for r in region2ami.keys():
    ec2 = boto3.client("ec2",region_name=r)
    i = ec2.describe_images(ImageIds=[region2ami[r]])
    result["AWSRegionToAMI"][r] = {
        "AMI": region2ami[r],
        "SnapshotId": i["Images"][0]["BlockDeviceMappings"][0]['Ebs']['SnapshotId']
    }
print yaml.dump(result, default_flow_style=False)
