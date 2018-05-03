

# Creating a basic AWS environment

## Step 1. A AWS account

If you do not have one already, [create an AWS Account](https://portal.aws.amazon.com/billing/signup#/start).

## Step 2. Setting up the AWS IAM user and AWS CLI

Next we need to set up your development environment, which means creating an  [AWS Identity and Access Management (IAM)](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html) user for use with Cromwell, and the [AWS Command Line Interface (AWS CLI)].

The easiest way to accomplish this follow [Step 1](https://aws.amazon.com/getting-started/tutorials/backup-to-s3-cli/#Step_1\:_Create_an_AWS_IAM_User) and [Step 2](https://aws.amazon.com/getting-started/tutorials/backup-to-s3-cli/#install-cli) of the ["Batch upload files to the cloud"](https://aws.amazon.com/getting-started/tutorials/backup-to-s3-cli/) 10-minute tutorial.

<table>
<tr><th>
:fire:  <span style="color: red;" >WARNING</span>
</th><td>
We <b>strongly</b> recommend following the
<a href='https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html'>IAM Security Best Practices</a> for securing your root AWS account and IAM users.
</td></tr>
</table>


<table>
<tr><th>
:pushpin:  <span style="color: blue;" >NOTE</span>
</th><td>
The rest of the tutorial walks through a simple exercise that shows how to create a <a href="https://aws.amazon.com/s3/"> Amazon S3</a> bucket and upload files to it using the AWS CLI. You can take this opportunity to upload some sequence data to S3 for analysis. :wink:
</td></tr>
</table>

## Step 3. Create a EC2 Key Pair

In order to SSH to virtual machines on AWS, you will need to create a [EC2 Key Pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html).

```shell
aws ec2 create-key-pair --key-name MyKeyPair --output text --query "KeyMaterial" > ${HOME}/MyKeyPair.pem
chmod 600 ${HOME}/MyKeyPair.pem
```

The above will create a new EC2 Key Pair named "MyKeyPair", will write out the RSA Private Certificate file into your root home directory, and change the permissions so that only you will be able to read the contents.

## Step 4. Ability to SSH into a Linux server

We assume that you are able to use the Key Pair created above to connect to Linux instances on AWS via SSH. If you are unsure about how this works, we recommend the ["Launch a Linux Virtual Machine"](https://aws.amazon.com/getting-started/tutorials/launch-a-virtual-machine/) tutorial which walks users through the process of starting a host on AWS, configuring your computer to connect over SSH, and connecting.

  
