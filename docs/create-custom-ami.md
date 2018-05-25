
# Creating a custom AMI for genomics

Genomics, the main use case for Cromwell, is a data-heavy workload and requires some modification to the standard AWS Batch processing environment. In particular, we need to scale underlying instance storage that Tasks/Jobs run on top of to meet unpredictable runtime demands.

A default AWS Batch environment assumes that the storage available to the [Amazon ECS-Optimized AMI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html) meets the needs of most customers. Any other needs, such as the large scratch storage requirements noted above or devices like GPUs, can be handled by providing AWS Batch with a custom [Compute Resource AMI](https://docs.aws.amazon.com/batch/latest/userguide/compute_resource_AMIs.html).

We have provided a script below ([Step 2](#step-2)) that launches and customizes the ECS-Optimized AMI. It will:

1. Launch and instance with a encrypted EBS volumes for the Docker container OS volumes and scratch space
2. Adjust the system settings to mount the scratch on instance start.
3. Install and configure a small service to monitor and automatically expand the Docker volumes scratch space by expanding the underlying EBS volume
4. Make the necessary adjustments to the Amazon Elastic Container Service (ECS) agent to work with AWS Batch
5. Adjust the network settings to allow for containers to query intance metadata for their Task IAM roles.
6. (Optional) Provide the Docker daemon credentials to access private registries such as Docker Hub.

## [Step 1.](id:step-1) Running the python script to bootstrap a EC2 instance

We have provided a Python script that sets up the above.

!!! note
    The provided script creates custom IAM resources, which may require elevated user permissions.

    If you encounter errors, it is likely account permissions are the root cause. You will need your AWS account administrator to create the custom AMI for you to use. Send them this guide.

```bash
# Download the script and install the requirements
curl -O https://cromwell-aws-batch/files/create-custom-ami.py
pip install boto3

# Run the script to see the help
python create-custom-ami.py --help
# Output:
# usage: create-custom-ami.py [-h] [--key-pair-name KEY_PAIR_NAME]
#                             [--vpc-id VPC_ID] [--subnet-id SUBNET_ID]
#
# Custom AMI bootstrap script
#
# optional arguments:
#   -h, --help            show this help message and exit
#   --key-pair-name KEY_PAIR_NAME
#   --vpc-id VPC_ID
#   --subnet-id SUBNET_ID
```


!!! note
    If you are curious, or a bit of a masochist, you can opt to create the custom AMI using a manual process. Refer to the ["Manually create the custom AMI using the Web console"](./create-custom-ami-manual.md) guide.

The `--key-pair-name` parameter defaults to `"custom-ami"`. The script will create a PEM file of the same name in the same directory as where you run the script from with the proper permissions.

```bash
[ec2-user@ip-172-31-30-130 ~]$ ls -l custom-ami.pem
-rw------- 1 ec2-user ec2-user 0 May 24 21:39 custom-ami.pem
```

Most new accounts have a [default VPC](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/default-vpc.html), but if this is not the case, or if you want to leverage a non-default VPC, then supply **both** the `--vpc-id` and `--subnet-id` parameters.

```bash
python create-custom-ami.py --key-pair-name myKeyPairName
# Output (after possibly some other output):
# Waiting on instance to pass health checks......................................................
# Resources that were created on your behalf:
#
#     * IAM Policy:   arn:aws:iam::123412341234:policy/CustomAmiEbsAdmin
#     * IAM Role:     arn:aws:iam::123412341234:role/CustomAmiEbsAdminRole
#     * EC2 Instance Profile: arn:aws:iam::123412341234:instance-profile/CustomAmiEbsAdminProfile
#     * EC2 Key Pair: myKeyPairName
#     * EC2 Security Group: sg-12ab1234
#     * EC2 Instance ID: i-00123001230012300
#
# To finish off the image, issue the following commands:
#
# Execute the following commands in a terminal window:
#
# ssh -i myKeyPairName.pem ec2-user@123.321.123.321
# sudo stop ecs
# sudo stop ebs-autoscale
# sudo rm -f /var/lib/ecs/data/ecs_agent_data.json /var/log/ebs-autoscale.log
# exit
# aws ec2 create-image \
#   --instance-id i-00123001230012300 \
#   --name "cromwell-aws-$(date '+%Y%m%d-%H%M%S')" \
#   --description "A custom AMI for use with AWS Batch"
#
#
# Take note the returned ImageId. We will use that for the AWS Batch setup.
```

The script takes about 5 minutes to run, you may want to take a :coffee: or :tea:  break at this point.

Once the script completes, you can SSH into the server to run the commands provided by the script to prepare the instance as a new AMI.

```bash
# From your development machine
aws ec2 create-image --instance-id i-00123001230012300 \
                     --name "cromwell-aws-$(date '+%Y%m%d-%H%M%S')" \
                     --description "A custom AMI for use with Cromwell on AWS Batch"
# Output:
# {
#     "ImageId": "ami-123abc456"
# }
```

Make a note of the AMI ID that was returned, we will need it for future sections.

## [Step 3.](id:step-3) Clean up

You can now terminate the instance that was used to create the custom AMIs

```bash
aws ec2 terminate-instances --instance-ids i-00123001230012300
```
