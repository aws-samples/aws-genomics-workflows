# Core: Custom Compute Resources

{{ deprecation_notice() }}

Genomics is a data-heavy workload and requires some modification to the defaults
used by AWS Batch for job processing.  To efficiently use resources, AWS Batch places multiple jobs on an worker instance.  The data requirements for individual jobs can range from a few MB to 100s of GB.  Instances running workflow jobs will not know beforehand how much space is required, and need scalable storage to meet unpredictable runtime demands.

To handle this use case, we can use a process that monitors a mountpoint on an instance and expands free space as needed based on capacity thresholds. This can be done using logical volume management and attaching EBS volumes as needed to the instance like so:

![Autoscaling EBS storage](images/ebs-autoscale.png)

The above process - "EBS autoscaling" - requires a few small dependencies and a simple daemon installed on the host instance.

By default, AWS Batch uses the [Amazon ECS-Optimized AMI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html)
to launch instances for running jobs.  This is sufficient in most cases, but specialized needs, such as the large storage requirements noted above, require customization of the base AMI.  Because the provisioning requirements for EBS autoscaling are fairly simple and light weight, one can use an EC2 Launch Template to customize instances.

## EC2 Launch Template

The simplest method for customizing an instance is to use an EC2 Launch Template.
This works best if your customizations are relatively light - such as installing
a few small utilities or making specific configuration changes.

This is because Launch Templates run a `UserData` script when an instance first launches.
The longer these scripts / customizations take to complete, the longer it will
be before your instance is ready for work.

Launch Templates are capable of pre-configuring a lot of EC2 instance options.
Since this will be working with AWS Batch, which already does a lot of automatic
instance configuration on its own, you only need to supply a `UserData`
script like the one below:

```text
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==BOUNDARY=="

--==BOUNDARY==
Content-Type: text/cloud-config; charset="us-ascii"

packages:
- jq
- btrfs-progs
- sed
- wget
- unzip
# add more package names here if you need them

runcmd:
- curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
- unzip -q /tmp/awscliv2.zip -d /tmp
- /tmp/aws/install

###
# add provisioning commands here
###

--==BOUNDARY==--
```

!!! info
    The MIME boundaries are required in the `UserData` script if the Launch Template is to be used with AWS Batch. See AWS Batch's [Launch Template Support](https://docs.aws.amazon.com/batch/latest/userguide/launch-templates.html) documentation to learn more.

In the set of provisioning commands you can add steps that retrieve and install [Amazon EBS Autoscale](https://github.com/awslabs/amazon-ebs-autoscale). For example, this documentation comes with a tarball that is publicly hosted on S3, allowing you to run the following to provision your instances:

```bash
cd /opt && wget https://aws-genomics-workflows.s3.amazonaws.com/artifacts/amazon-ebs-autoscale.tgz && tar -xzf amazon-ebs-autoscale.tgz
sh /opt/ebs-autoscale/install.sh
```

The above will install an `ebs-autoscale` daemon on an instance.  By default it will
add a 100GB EBS volume to the logical volume mounted at `/scratch`.

The mount point is specific to your use case, and `/scratch` is considered a generic default.  For instances launched by AWS Batch for running containerized jobs, a good option is to apply Amazon EBS Autoscaling to `/var/lib/docker` - the location where Docker stores container volumes and metadata and is the location that containers use for their filesystems. Making this auto-expand allows containers to pull in any amount of data they need.

## Flexible provisioning

Provisioning needs can change over time. For instance, updrades to existing software or swapping out tools altogether. While you could explicitly write all the commands you initially need in `UserData`, any future changes will require creating a new revision of the Launch Template and subsequently require rebuilding AWS Batch resources. For more flexibility, you can store your provisioning scripts on S3 and have the Launch Template retrieve and run them. This allows you to create a generic and relatively immutable Launch Template, and update provisioning steps by uploading new scripts to S3.

You can automate this further using a Git repository like [AWS CodeCommit](https://aws.amazon.com/codecommit/) to track versions of your provisioning scripts and use CI/CD pipelines with [AWS CodeBuild](https://aws.amazon.com/codebuild/) and [AWS CodePipeline](https://aws.amazon.com/codepipeline/) to deploy new releases to S3.

All of the above can be create in an automated fashion with CloudFormation. Look at the source code for the template below to see how this is done.

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | :--: |
{{ cfn_stack_row("Provisioning Code", "GWFCore-Code", "gwfcore/gwfcore-code.template.yaml", "Creates and installs code and artifacts used to run subsequent templates and provision EC2 instances", enable_cfn_button=False) }}

!!! info
    The launch button has been disabled above since this template is part of a set of nested templates. It is not recommended to launch it independently of its intended parent stack.

## Creating an EC2 Launch Template

Instructions on how to create a launch template are below.  Once your Launch Template is created, you can reference it when you setup resources in AWS Batch to ensure that jobs run therein have your customizations available
to them.

### Automated via CloudFormation

You can use the following CloudFormation template to create a Launch Template
suitable for your needs.

| Name | Description | Source | Launch Stack |
| -- | -- | :--: | :--: |
{{ cfn_stack_row("EC2 Launch Template", "GWFCore-LT", "gwfcore/gwfcore-launch-template.template.yaml", "Creates an EC2 Launch Template that provisions instances on first boot for processing genomics workflow tasks.", enable_cfn_button=False) }}

!!! info
    The launch button has been disabled above since this template is part of a set of nested templates. It is not recommended to launch it independently of its intended parent stack.

### Manually via the AWS Console

* Go to the EC2 Console
* Click on "Launch Templates" (under "Instances")
* Click on "Create launch template"
* Under "Launch template name and description"

    * Use "genomics-workflow-template" for "Launch template name"

* Under "Storage volumes"
  
    * Click "Add new volume" - this will add an entry called "Volume 3 (custom)"
        * Set **Size** to **100 GiB**
        * Set **Delete on termination** to **Yes**
        * Set **Device name** to **/dev/xvdba**
        * Set **Volume type** to **General purpose SSD (gp2)**
        * Set **Encrypted** to **Yes** 

!!! info
    **Volume 1** is used for the root filesystem.  The default size of 8GB is typically sufficient.

    **Volume 2** is the default volume used by Amazon ECS Optimized AMIs for Docker image and metadata volume using Docker's `devicemapper` driver.  We'll be replacing this volume with the custom one you created, but need to keep it for compatibility.

    **Volume 3** (the one you created above) will be used for job scratch space.  This will be mapped to `/var/lib/docker` which is used for container storage - i.e. what each running container will use to create its internal filesystem.

* Expand the "Advanced details" section

    * Add the following script to **User data**

```text
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==BOUNDARY=="

--==BOUNDARY==
Content-Type: text/cloud-config; charset="us-ascii"

packages:
- jq
- btrfs-progs
- sed
- wget
- unzip
# add more package names here if you need them

runcmd:
- curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
- unzip -q /tmp/awscliv2.zip -d /tmp
- /tmp/aws/install

###
# add provisioning commands here
###

--==BOUNDARY==--
```

!!! important
    You will need to replace `# add provisioning commands here` with something appropriate

* Click on "Create launch template"

## Custom AMIs

A slightly more involved method for customizing an instance is
to create a new AMI based on the ECS Optimized AMI.  This is good if you have
a lot of customization to do - lots of software to install and/or need large
datasets preloaded that will be needed by all your jobs.

You can learn more about how to [create your own AMIs in the EC2 userguide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html).

If needed, you can use Custom AMIs and Lauch Templates together - e.g. for a case where you need to ship preloaded datesets or use AMI packaged software from the AWS Marketplace and use the flexible provisioning options Launch Templates provide.

!!! note
    This is considered advanced use.  All documentation and CloudFormation templates hereon assumes use of EC2 Launch Templates.
