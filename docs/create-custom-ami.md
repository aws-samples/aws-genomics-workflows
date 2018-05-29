
# Creating a custom AMI for genomics

Genomics, the main use case for Cromwell, is a data-heavy workload and requires some modification to the standard AWS Batch processing environment. In particular, we need the underlying instance storage that Tasks/Jobs run on top of to meet unpredictable runtime demands.

A default AWS Batch environment assumes that the storage available to the [Amazon ECS-Optimized AMI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html) meets the needs of most customers. Any other needs, such as the large scratch storage requirements noted above, or devices like GPUs, can be handled by providing AWS Batch with a custom [Compute Resource AMI](https://docs.aws.amazon.com/batch/latest/userguide/compute_resource_AMIs.html).

We have provided a script (see [Step 1](#step-1)) that launches and customizes the ECS-Optimized AMI, and subsequently produces a new AMI. The script will:

1. Launch an EC2 instance from the ECS-Optimized AMI with a encrypted EBS volumes for the Docker containers  and scratch space
2. Adjust the system settings to mount the scratch on instance start.
3. Install and configure a small service to monitor and automatically expand the scratch space by adding new EBS volume
4. Make the necessary adjustments to the Amazon Elastic Container Service (ECS) agent to work with AWS Batch
5. Adjust the network settings to allow for containers to query instance metadata for their Task IAM roles.

## [Step 1.](id:step-1) Running the python script to bootstrap a EC2 instance

We have provided a Python script that sets up the above.


TODO: Update this to new parameter set
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
    If you are unable to leverage this script, you can opt to create the custom AMI using a manual process. Refer to the ["Manually create the custom AMI using the Web console"](./create-custom-ami-manual.md) guide.

The `--key-pair-name` parameter defaults to `"genomics-ami"`. The script will create the key pair if it does not exist and write out a PEM file (`genomics-ami.pem`) to the same directory as where you ran the script. If the key pair already exists, we assume that you know how to find it for your use.

By default, the script leaves the new instance up for you to SSH into and review. If you provide the `--terminate-instance` parameter, the script will terminate the instance for you after the AMI is successfully created. 


Most new accounts have a [default VPC](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/default-vpc.html), but if this is not the case, or if you want to leverage a non-default VPC, then supply **both** the `--vpc-id` and `--subnet-id` parameters.

TODO: Update this to new output
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

The script takes about 10 minutes to run, you may want to take a :coffee: or :tea:  break at this point.

Once the script completes, you have a new AMI ID to give to AWS Batch. Make a note of the AMI ID that was returned, we will need it for future sections. If you chose to not terminate the instance,  you can also SSH into the server to review the services. Be sure to terminate the instance after you are done. Here is an example using the AWS CLI.

```bash
aws ec2 terminate-instances --instance-ids i-00123001230012300
```
