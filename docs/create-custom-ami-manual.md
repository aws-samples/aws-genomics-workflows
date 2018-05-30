# Manually create a custom Compute Resource AMI for AWS Batch

A good starting base for a AWS Batch custom AMI for genomics is the [Amazon ECS-Optimized AMI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html). Specifically the Amazon ECS-optimized AMI is preconfigured and tested on Amazon ECS by AWS engineers. It is the simplest AMI for you to get started and to get your containers running on AWS quickly.

The current Amazon ECS-optimized AMI (amzn-ami-2017.09.l-amazon-ecs-optimized) consists of:

* The latest minimal version of the Amazon Linux AMI
* The latest version of the Amazon ECS container agent (1.17.3)
* The recommended version of Docker for the latest Amazon ECS container agent (17.12.1-ce)
* The latest version of the ecs-init package to run and monitor the Amazon ECS agent (1.17.3-1)

## [Step 1.](id:step-1) Getting the AMI ID of an ECS-Optimized AMI for your region

You will need the AMI ID of the latest ECS-Optimized AMI. You can get a list of the current AMI IDs by region on the [documentation page](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html) documentation page.


[![Table of Amazon ECS-Optimized AMIs](cromwell-ecs-opt-amis-table.png)](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html)

Click on the appropriate AMI ID for your region.

## [Step 2.](id:step-2) Launch and configure a new instance

![EC2 we console AMIs](./images/gen-ami-launch-instance-size.png)

![EC2 we console AMIs](./images/gen-ami-launch-storage.png)

![EC2 we console AMIs](./images/gen-ami-launch-userdata.png)

![EC2 we console AMIs](./images/gen-ami-launch-security-group.png)

![EC2 we console AMIs](./images/gen-ami-launch-review.png)

![EC2 we console AMIs](./images/gen-ami-launch-launch.png)

![EC2 we console AMIs](./images/gen-ami-launch-security-group.png)


## [Step 4.](id:step-4) OPTIONAL: Configure ECS for private Docker registry use

!!! note
    If you want to leverage **private** Docker registries, refer to the
    [ECS documentation on private registry authentication](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/private-auth.html).  We will not cover this topic here.

## [Step 5.](id:step-5) Create a new Amazon Machine Image

Exit the SSH session and create a new AMI from your development machine using the web console.

Make a note of the AMI ID, we will need it for future sections.

![EC2 we console AMIs](./images/gen-ami-ami-id.png)

## [Step 6.](id:step-6) Clean up

You can now terminate the instance that was used to create the custom AMIs

```bash
aws ec2 terminate-instances --instance-ids ${INSTANCE_ID}
```
