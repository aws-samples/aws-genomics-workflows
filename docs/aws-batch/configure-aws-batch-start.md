# Introduction on AWS Batch for genomics workflows

## TL;DR

AWS Batch provides a queue to send jobs to, and will manage the underlying compute necessary to run those jobs. For the impatient, skip to the next step ["Creating a custom AMI for genomics"](./create-custom-ami.md).

## The detailed explaination

[AWS Batch](https://aws.amazon.com/batch/) is a managed service that helps you efficiently run batch computing workloads on the AWS Cloud. Users submit jobs to job queues, specifying the application to be run and their jobs’ CPU and memory requirements. AWS Batch is responsible for launching the appropriate quantity and types of instances needed to run your jobs.



AWS Batch removes the undifferentiated heavy lifting of configuring and managing compute infrastructure, allowing you to instead focus on your applications and users. This is demonstrated in the [How AWS Batch Works](https://www.youtube.com/watch?v=T4aAWrGHmxQ) video.

AWS Batch manages the following resources:

* Job Definitions
* Job Queues
* Compute Environments


A [job definition](http://docs.aws.amazon.com/batch/latest/userguide/job_definitions.html) specifies how jobs are to be run—for example, which Docker image to use for your job, how many vCPUs and how much memory is required, the IAM role to be used, and more.

Jobs are submitted to [job queues](http://docs.aws.amazon.com/batch/latest/userguide/job_queues.html) where they reside until they can be scheduled to run on Amazon EC2 instances within a compute environment. An AWS account can have multiple job queues, each with varying priority. This gives you the ability to closely align the consumption of compute resources with your organizational requirements.

[Compute environments](http://docs.aws.amazon.com/batch/latest/userguide/compute_environments.html) provision and manage your EC2 instances and other compute resources that are used to run your AWS Batch jobs. Job queues are mapped to one more compute environments and a given environment can also be mapped to one or more job queues. This many-to-many relationship is defined by the compute environment order and job queue priority properties.

The following diagram shows a general overview of how the AWS Batch resources interact.

![AWS Batch environment](https://d2908q01vomqb2.cloudfront.net/1b6453892473a467d07372d45eb05abc2031647a/2018/04/23/AWSBatchresoucreinteract-diagram.png)

We will be leveraging [AWS CloudFormation](https://aws.amazon.com/cloudformation/), which allows developers and systems administrators to easily create and manage a collection of related AWS resources (called a CloudFormation stack) by provisioning and updating them in an orderly and predictable way.


The provided CloudFormation templates will create the necessary resource for AWS within your Amazon VPC.

![AWS CloudFormation Stack launching a AWS Batch Environment](https://d2908q01vomqb2.cloudfront.net/1b6453892473a467d07372d45eb05abc2031647a/2018/04/23/Picture1-1.png)


Specifically, the templates will create:

1. A new Amazon S3 bucket to write results to.
2. A new Amazon S3 bucket to send log data to.
3. A AWS Batch Compute Environment that utilizes [EC2 Spot instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-spot-instances.html) for cost-effective computing
4. A AWS Batch Compute Environment that utilizes EC2 on-demand (e.g. [public pricing](https://aws.amazon.com/ec2/pricing/on-demand/)) instances for high-priority work that can't risk job interruptions or delays due to insufficient Spot capacity.
5. A default AWS Batch Job Queue that utilizes the Spot compute environment first, but falls back to the on-demand compute environment if there is spare capacity already there.
6. A high-priority AWS Batch Job Queue that leverages the on-demand and Spot CE's (in that order) and has higher priority than the default queue.

Here is a conceptual diagram of the proposed architecture:

![AWS Batch environment for genomics](https://d2908q01vomqb2.cloudfront.net/1b6453892473a467d07372d45eb05abc2031647a/2018/04/23/Picture2.png)


## Next Step: Setting up a custom AMI for genomics workflows

Genomics is a data-heavy workload and requires some modification to the standard AWS Batch processing environment. In particular, we need to scale underlying instance storage that Tasks/Jobs run on top of to meet unpredictable runtime demands.

**[Create a custom AMI for genomics workloads](./create-custom-ami.md)**
