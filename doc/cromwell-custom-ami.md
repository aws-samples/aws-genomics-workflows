
# Creating a custom AMI for genomics

Genomics, the main use case for Cromwell, is a data-heavy workload and requires some modification to the standard AWS Batch processing environment. In particular, we need to scale underlying instance storage that Tasks/Jobs run on top of to meet unpredictable runtime demands.

The provided [CloudFormation template]() for creating
Specifically we will:

1. Launch and instance with a encrypted EBS volume for scratch space
2. Create a logical volume group using the EBS volume, format it for a filesystem, and adjust the system settings to mount the scratch on instance start.
3. Install and configure a small service to monitor and automatically expand scratch space.
4. Make the necessary adjustments to the Amazon Elastic Container Service (ECS) to work with AWS Batch.
5. Adjust the network settings to allow for containers to query intance metadata for their Task IAM roles.
6. (Optional) Provide the Docker daemon credentials to access private registries such as Docker Hub.

A good starting base for a AWS Batch custom AMI for genomics is the [Amazon ECS-Optimized AMI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html). Specifically the Amazon ECS-optimized AMI is preconfigured and tested on Amazon ECS by AWS engineers. It is the simplest AMI for you to get started and to get your containers running on AWS quickly.

The current Amazon ECS-optimized AMI (amzn-ami-2017.09.l-amazon-ecs-optimized) consists of:

* The latest minimal version of the Amazon Linux AMI
* The latest version of the Amazon ECS container agent (1.17.3)
* The recommended version of Docker for the latest Amazon ECS container agent (17.12.1-ce)
* The latest version of the ecs-init package to run and monitor the Amazon ECS agent (1.17.3-1)

## [Step 1.](id:step-1) Getting the AMI ID of an ECS-Optimized AMI for your region

You will need the AMI ID of the latest ECS-Optimized AMI. You can get a list of the current AMI IDs by region on the [documentation page](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#w301aac19c15c15c12) documentation page.


[![Table of Amazon ECS-Optimized AMIs](../images/cromwell-ecs-opt-amis-table.png)](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html)

Copy the appropriate AMI ID for the next step (e.g. `ami-aff65ad2`).

## Step X. Query the image metadata to get the `BlockDeviceMappings`

```bash
aws ec2 describe-images --image-ids <YOUR AMI ID> \
    --output json \
    --query "Images[0].{ImageId: ImageId, BlockDeviceMappings: BlockDeviceMappings}" \
    > run-instances-input.json
```

The `run-instances-input.json` file looks like this for `ami-aff65ad2`:

```javascript
{
    "BlockDeviceMappings": [
        {
            "DeviceName": "/dev/xvda",
            "Ebs": {
                "Encrypted": false,
                "DeleteOnTermination": true,
                "VolumeType": "gp2",
                "VolumeSize": 8,
                "SnapshotId": "snap-0888b555c45893ab1"
            }
        },
        {
            "DeviceName": "/dev/xvdcz",
            "Ebs": {
                "Encrypted": false,
                "DeleteOnTermination": true,
                "VolumeType": "gp2",
                "VolumeSize": 22
            }
        }
    ],
    "ImageId": "ami-aff65ad2"
}
```

First, we will make two changes to `BlockDeviceMappings`; encrypt the Docker volume, and add another encrypted EBS 10GB volume for scratch space.

```javascript
{
    "BlockDeviceMappings": [
        {
            "DeviceName": "/dev/xvda",
            "Ebs": {
                "Encrypted": false,
                "DeleteOnTermination": true,
                "VolumeType": "gp2",
                "VolumeSize": 8,
                "SnapshotId": "snap-0888b555c45893ab1"
            }
        },
        {
            "DeviceName": "/dev/xvdcz",
            "Ebs": {
                "Encrypted": true,
                "DeleteOnTermination": true,
                "VolumeType": "gp2",
                "VolumeSize": 22
            }
        },
        {
            "DeviceName": "/dev/xvdb",
            "Ebs": {
                "Encrypted": true,
                "DeleteOnTermination": true,
                "VolumeType": "gp2",
                "VolumeSize": 10
            }
        }

    ],
    "ImageId": "ami-aff65ad2"
}
```

Next, we will launch an `t2.large` instance with, adding in some more launch parameters on the command line. In particular, we want to include a EC2 user data block to bootstrap the other parts of the installation.

```bash
curl -O https://cromwell-aws-batch.s3.amazonaws.com/files/custom-ami-bootstrap-userdata.txt
aws ec2 run-instances --cli-input-json "'$(cat run-instances-input.json)'" \
                      --instance-type t2.large \
                      --associate-public-ip-address \
                      --key-name <YOUR KEY PAIR NAME> \
                      --subnet-id <YOUR SUBNET ID> \
                      --security-group-ids <YOUR SECURITY GROUP FOR SSH> \
                      --user-data file://custom-ami-bootstrap-userdata.txt
# Output:
# instance ID
```

Wait a few minutes (grab yourself some :coffee: or :tea:) and then SSH into the instance to check if the bootstrap process succeeded.

```bash
# example SSH session
ssh -i MyKeyPair.pem ec2-user@ec2-32-32-32-32.compute-1.amazonaws.com

# did the required packages install?
which aws jq
# Output:
# /usr/bin/aws
# /usr/bin/jq

# check the scratch filesystem
df -h /docker_scratch
# Output:
# Filesystem                                      Size  Used Avail Use% Mounted on
# /dev/mapper/docker_scratch-docker_scratch_pool  9.8G   23M  9.2G   1% /docker_scratch
grep docker_scratch /etc/fstab
# Output:
# /dev/docker_scratch/docker_scratch_pool	/docker_scratch	ext4	defaults	0	0

# make sure the docker scratch autoscale service is up
sudo status docker-ebs-autoscale
# Output:
# docker-ebs-autoscale start/running, process 2010

# check for ECS service configuration prior to snapshot
sudo status ecs
# Output:
# ecs stop/waiting

# Check iptables
sudo service iptables status | grep 169.254.170.2
# Output:
# 1    DNAT       tcp  --  0.0.0.0/0            169.254.170.2        tcp dpt:80 to:127.0.0.1:51679
# 1    REDIRECT   tcp  --  0.0.0.0/0            169.254.170.2        tcp dpt:80 redir ports 51679
```

<table>
<tr><th> :hamburger: Note </th></tr>
<tr><td>
If you want to leverage <b>private Docker registries</b>, see
<A href="#XXX"> section XXX</a>
below on how to configure you instance to be able to do this prior to making an AMI image.
</td></tr>
</table>

If everything looked good, then exit the SSH session and create a new AMI

```bash
# From your development machine
aws ec2 create-image --instance-id <YOUR INSTANCE ID> \
                     --name "cromwell-aws-$(date '+%Y%m%d-%H%M%S')" \
                     --description "A custom AMI for use with Cromwell on AWS Batch"
# Output:
# AMI ID
```



## [Step 2.](id:step-2) Configure the instance launch

We recommend that you select the `t2.medium` instance size when launching

![T2.medium instance size](../images/cromwell-ecs-instance-size.png)

You'll want to confirm that the instance is auto-assigned a public IP so that you can connect to it via SSH.

![instance details](../images/cromwell-ami-instance-details.png)

Next add a new 10GB EBS volume for scratch space. Make sure that you check off the box for deleting the volumes on termination, and also assign a encryption key (the default EBS one is fine).

![instance volumes](../images/cromwell-ami-ebs-add.png)
![instance volumes encryption key](../images/cromwell-ami-ebs-encryption-key.png)

Click through the next two screens for adding tags. On Step 6. "Configuring Security Group" confirm that the instance will allow inbound SSH traffic to port 22.

![instance security group](../images/cromwell-ami-sg-ssh.png)

Next, click on "Review and Launch" --> "Launch" to get to the dialog confirming that you have a EC2 Key Pair. We created one in the [Prerequisites] guide, you can use that one, but otherwise create a new key pair.

![instance key pair choose](../images/cromwell-ami-key-pair-1.png)

![instance key pair choose](../images/cromwell-ami-key-pair-2.png)

Once the instance is running, connect to it via SSH

![instance IP address](../images/cromwell-ami-public-ip.png)

```bash
[user@machine ~]$ ssh -i MyKeyPair.pem ec2-user@123.12.12.123
The authenticity of host '123.12.12.123 (123.12.12.123)' cannot be established.
ECDSA key fingerprint is SHA256:yMyvY8wLCiL+aB0Bbu5SAB2pT2R8vMCi+xKqjlxbkJ/Bw.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '123.12.12.123' (ECDSA) to the list of known hosts.
Last login: Tue May  1 04:16:35 2018 from 72.21.1.64

   __|  __|  __|
   _|  (   \__ \   Amazon ECS-Optimized Amazon Linux AMI 2017.09.l
 ____|\___|____/

For documentation, visit http://aws.amazon.com/documentation/ecs
4 package(s) needed for security, out of 7 available
Run "sudo yum update" to apply all updates.
Amazon Linux version 2018.03 is available.
[ec2-user@ip-10-0-0-135 ~]$
```

## [Step 3.](id:step-3) Creating the scratch volume

Here we will create a logical volume group to serve as scratch space for Docker containers. Below are simply the commands that are needed, for a full explaination of what is happening, refer to the ["Notes on Docker EBS autoscaling"]() guide.

Copy and paste the commands below, they will leverage the LVM2 capabilities to create the scratch volume for the Docker containers.

```bash
# run these as the root user (e.g. 'sudo su -' )
cd /tmp
curl -O https://cromwell-aws-batch.s3.amazonaws.com/files/docker-ebs-autoscale.tar.gz

# create the new logical volume, format, and mount
sh src/creat-logical-volume.sh /dev/xvdb docker_scratch docker_scratch_pool /docker_scratch

# install the
cp src/etc/init/docker-ebs-autoscale.conf /etc/init/docker-ebs-autoscale.conf
cp src/usr/local/bin/docker-ebs-autoscale.sh /usr/local/bin/docker-ebs-autoscale.sh
cp src/etc/logrotate.d/docker-ebs-autoscale /etc/logrotate.d/docker-ebs-autoscale
initctl reload-configuration
initctl start docker-ebs-autoscale

# remove the temp files (optional)
rm -fr src docker-ebs-autoscale.tar.gz
```

You can see that the `/docker_scratch` volume is mounted, formatted and is empty

```bash
[root@ip-10-0-0-135 bin]# ls -l /docker_scratch/
total 16
drwx------ 2 root root 16384 May  1 05:14 lost+found

[root@ip-10-0-0-135 bin]# df -h /docker_scratch/
Filesystem                                      Size  Used Avail Use% Mounted on
/dev/mapper/docker_scratch-docker_scratch_pool  9.8G   23M  9.2G   1% /docker_scratch
```

## [Step 4.](id:step-4) Configuring ECS for use snapshotting the AMI

First, stop the ECS service and remove the ECS runtime configuration file

```bash
# run these as the root user (e.g. 'sudo su -' )
stop ecs

rm -rf /var/lib/ecs/data/ecs_agent_data.json
```

Next, we will adjust the instance network to allow containers to query for AWS credentials via the [instance metadata](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html).

```shell
sudo sysctl -w net.ipv4.conf.all.route_localnet=1
sudo iptables -t nat -A PREROUTING -p tcp -d 169.254.170.2 --dport 80 -j DNAT --to-destination 127.0.0.1:51679
sudo iptables -t nat -A OUTPUT -d 169.254.170.2 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 51679
sudo service iptables save
```

You can get more information about what just happened from the ECS documentation on [IAM roles for Tasks](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html)


## [Step XXX.](id:XXX) (Optional) Configuring AWS for access to private Docker Hub repositories

Since AWS Batch relies on ECS, we leverage the ECS container agent's ability to [authenticate against private registries](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/private-auth.html#enabling-private-registry)

Specifially, you need a JSON block of your registry's URL, username, email, and password. Here is an example for Docker Hub:

```javascript
{
  "https://index.docker.io/v1/": {
    "username": "my_name",
    "password": "my_password",
    "email": "email@example.com"
  }
}
```

Open the /etc/ecs/ecs.config file and add the ECS_ENGINE_AUTH_TYPE and ECS_ENGINE_AUTH_DATA values for your registry and account.

```bash
sudo vi /etc/ecs/ecs.config
```

Then we need to add in the `ECS_ENGINE_AUTH_TYPE` and `ECS_ENGINE_AUTH_DATA` like so:

```
ECS_ENGINE_AUTH_TYPE=docker
ECS_ENGINE_AUTH_DATA={"https://index.docker.io/v1/":{"username":"my_name","password":"my_password","email":"email@example.com"}}
```

### [Step 5.](id:step-5) Snapshotting the AMI

Finally, go back to the EC2 console and create the AMIs

![creating the AMI 1](../images/cromwell-ami-create-image-1.png)
![creating the AMI 2](../images/cromwell-ami-create-image-2.png)

Make a note of the AMI ID using the console

![Getting the AMI ID](../images/cromwell-ami-create-image-3.png)
