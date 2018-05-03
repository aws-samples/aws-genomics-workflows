# Autoscaling Storage using EBS Volumes for AWS Batch

With [AWS Batch](https://aws.amazon.com/batch/), users are able to define the required CPU and Memory resources within a [`Job Definition`](https://docs.aws.amazon.com/batch/latest/userguide/job_definitions.html), as well as override the default values at runtime when they submit a [`Job`](https://docs.aws.amazon.com/batch/latest/userguide/jobs.html), but users are **not** able to specify how much storage to allocate for any given `Job`.

 It is also sometimes the case that it is difficult to predict the amount of storage space needed *a priori* to running a given `Job` with a set of inputs, causing a job failure and requiring advanced retry logic that allocates more resources as necessary. Databricks has [a great blog post](https://databricks.com/blog/2017/12/01/transparent-autoscaling-of-instance-storage.html) on the various challenges with storage management in high-scale compute workloads. They also describe how they solved this issue by leveraging [Logical Volume Manager (LVM)](https://sourceware.org/lvm2/) in Linux and [Amazon EBS](https://aws.amazon.com/ebs/) volumes.

This repository is a independent implementation of that described work. Specifically this repository containst a service for monitoring and expanding the disk space available to Docker containers on a EC2 instance. Since this service was developed for the [Amazon ECS-Optimized AMI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html), it has some assumptions, such as:

* Utilizes [Upstart](http://upstart.ubuntu.com) as the init system
* That the LVM Volume Group name is "docker"
* That the LVM Logical Volume name is "docker-pool"

You can modify the names of the VG and LV in the upstart configuration file.

## Installation

Copy the following files into the right place.

```bash
curl -O https://cromwell-aws-batch.s3.amazonaws.com/files/docker-ebs-autoscale.tar.gz
...
```

Then start the service

```shell
sudo start docker-ebs-autoscale
```
