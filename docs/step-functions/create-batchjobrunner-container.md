# Creating the job management container

For a job management container (`BatchJobRunner`) we will need to install the necessary tooling to support temporary runtime directories, downloads/uploads from S3, and running sibling containers that actually execute the desired process.


```docker
FROM amazonlinux:2

RUN yum update -y && \
    yum install -y awscli docker jq unzip && \
    yum clean all

RUN cd /opt && \
    curl -o batch-job-runner.tgz https://aws-genomics-workflows/aws-batch-genomics.tar.gz && \
    tar -xzf aws-batch-genomics.tar.gz && rm aws-batch-genomics.tar.gz

CMD ["/opt/aws-batch-genomics/src/batch/bin/batch-job-runner.sh"]
```

The above Dockerfile defines the source operating system ([Amazon Linux 2](https://aws.amazon.com/amazon-linux-2/) and installs all of the necessary packages and dependencies for the job manager script (`batch-job-runner.sh`), and then sets that script as the container's entry point. Assuming your working directory has a file with the above contents, create the container like so:

```shell
docker build .
```
