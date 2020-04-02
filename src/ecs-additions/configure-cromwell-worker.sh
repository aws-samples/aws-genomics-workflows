#! /bin/bash
set -ev

if [ -e "/etc/docker/daemon.json" ];
# If the file exsists then add or update the storage-driver kv pair to use btrfs, otherwise create the file
then
  jq '. + {"storage-driver": "btrfs"}' < /etc/docker/daemon.json > /tmp/daemon.json && mv /tmp/daemon.json /etc/docker/daemon.json
else
  jq -n '{"storage-driver": "btrfs"}' > /etc/docker/daemon.json
fi

# install aws cli v2, currently done in the aws-genomics-launch-template
# cd /tmp && curl --silent --retry 5 --retry-connrefused "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip -q awscliv2.zip && sudo ./aws/install

# install ebs-autoscale
cd /opt && curl --silent --retry 5 --retry-connrefused "https://d52iwap9aqlil.cloudfront.net/aws-ebs-autoscale.tgz" -o "aws-ebs-autoscale.tgz" && tar -xzf aws-ebs-autoscale.tgz
# mount an autoscalable drive at /var/lib/docker so that docker auto expands
sh /opt/ebs-autoscale/bin/init-ebs-autoscale.sh /var/lib/docker /dev/sdc > /var/log/init-ebs-autoscale.log 2>&1
# install the fetch_and_run script to pull task execution scripts from s3
cd /usr/local/bin && curl --retry 5 --retry-connrefused "https://d52iwap9aqlil.cloudfront.net/fetch_and_run.sh" -o "fetch_and_run.sh" && chmod a+x ./fetch_and_run.sh

#try and determine how to start ecs
if [ -e "/usr/bin/systemctl" ];
then
  #amzn linux 2/ recent RHEL or similar
  systemctl restart --no-block ecs
else
  #amzn linux 1 or older linux distros
  service docker start
  start ecs
fi
