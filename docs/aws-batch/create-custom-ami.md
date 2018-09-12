
# Custom AWS Batch compute resources for genomics

A default AWS Batch environment assumes that the storage available to the [Amazon ECS-Optimized AMI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html) meets the needs of most customers. Any other needs, such as the large scratch storage requirements noted above, or devices like GPUs, can be handled by providing AWS Batch with a custom [Compute Resource AMI](https://docs.aws.amazon.com/batch/latest/userguide/compute_resource_AMIs.html).

Genomics is a data-heavy workload and requires some modification to the standard AWS Batch processing environment. In particular, we need the underlying instance storage that tasks ([AWS Batch Jobs](https://docs.aws.amazon.com/batch/latest/userguide/jobs.html)) run on top of to meet unpredictable runtime demands.

We have provided a script (see [the next section](#create-a-custom-ami)) that customizes the ECS-Optimized AMI to add a working directory that the Jobs will use to write data. That directory will be monitored by a process that inspects the free space available and adds more EBS volumes and expands the filesystem on the fly, like so:

![Autoscaling EBS storage](images/autoscale-ebs.gif)


## Create a custom AMI

We have provided a Python script that sets up the above.

The script will:

1. Launch an EC2 instance from the ECS-Optimized AMI with a encrypted EBS volumes for the Docker containers  and scratch space
2. Adjust the system settings to mount the scratch on instance start.
3. Install and configure a small service to monitor and automatically expand the scratch space by adding new EBS volume
4. Make the necessary adjustments to the Amazon Elastic Container Service (ECS) agent to work with AWS Batch
5. Adjust the network settings to allow for containers to query instance metadata for their Task IAM roles.


```bash
# Download the source and install the requirements
curl -O https://aws-genomics-workflows.s3.amazonaws.com/artifacts/aws-custom-ami.tgz
tar -xzf aws-custom-ami.tgz && rm aws-custom-ami.tgz
cd aws-custom-ami
pip install -r requirements.txt


# Run the script to see the help
./create-custom-ami.py --help
# Output:
# usage: create-genomics-ami.py [-h] [--profile PROFILE] [--region REGION_NAME]
#                               [--scratch-mount-point SCRATCH_MOUNT_POINT]
#                               [--key-pair-name KEY_PAIR_NAME]
#                               [--user-data USER_DATA_FILE]
#                               [--src-ami-id SRC_AMI_ID] [--vpc-id VPC_ID]
#                               [--subnet-id SUBNET_ID]
#                               [--security-group-id SECURITY_GROUP_ID]
#                               [--instance-profile-name INSTANCE_PROFILE_NAME]
#                               [--max-instance-creation-attempts MAX_INSTANCE_CREATION_ATTEMPTS]
#                               [--ebs-encryption | --no-ebs-encryption]
#                               [--no-health-checks] [--no-ami]
#                               [--ami-name AMI_NAME]
#                               [--ami-description AMI_DESCRIPTION]
#                               [--iam-cleanup]
#                               [--terminate-instance | --no-terminate-instance]
#
# Creates a custom AMI for genomics workloads
```


!!! note
    If you are unable to leverage this script, you likely don't have the permissions to work in this enviroment. Talk with your account administrator and show them this guide.

The `--key-pair-name` parameter defaults to `"genomics-ami`. If the key pair does not exist yet, the script will create it and write out the PEM file to the same directory as where you ran the script. If the key pair already exists, we assume that you know how to find the PEM file and how to use it.

By default, the script terminates the new instance. If you want to leave the instance up to SSH into and review, provice the `--no-terminate-instance` argument.

Most new accounts have a [default VPC](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/default-vpc.html), but if this is not the case, or if you want to leverage a non-default VPC, then supply **both** the `--vpc-id` and `--subnet-id` parameters.

The script takes about 10 minutes to run, you may want to take a :coffee: or :tea:  break at this point.

Here is example output from running the script, providing a value for the key pair name (_values for ID's have been changed_):

```bash
$ ./create-genomics-ami.py \
    --region us-west-2 \
    --key-pair-name my-key-pair \
    --user-data ./cromwell-genomics-ami.cloud-init.yaml

Using profile: default
Getting security group named: GenomicsAmiSG-subnet-********
Key Pair [ my-key-pair ] exists.
Source AMI ID: ami-093381d21a4fc38d1
Using user-data file:  ./cromwell-genomics-ami.cloud-init.yaml
Creating EC2 instance . done
Getting EC2 instance IP ... [ ***.***.***.*** ]
Checking EC2 Instance health .................................................... available and healthy
Creating AMI ........................new AMI [ami-*****************] created.
Terminating instance ...terminated.
Resources that were created on your behalf:

    * AWS Region: us-west-2

    * IAM Instance Profile: GenomicsAMICreationRole_20180827-155952

    * EC2 Key Pair: my-key-pair
    * EC2 Security Group: sg-*****************
    * EC2 Instance ID: i-*****************
    * EC2 AMI ImageId: ami-*****************    <== NOTE THIS ID
        * name: genomics-ami-20180907-153312
        * description: A custom AMI for use with AWS Batch with genomics workflows
```

Once the script completes, you have a new AMI ID to give to AWS Batch. Make a note of the AMI ID that was returned, we will need it for future sections.

If you chose to not terminate the instance,  you can also SSH into the server to review the services. Be sure to terminate the instance after you are done. Here is an example using the AWS CLI.

```bash
aws ec2 terminate-instances --instance-ids i-*****************
```
