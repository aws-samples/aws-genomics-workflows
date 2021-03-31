#! /bin/bash

###
#
# This script is not currently in use as Amazon Linux2 is not yet the default for AWS batch. When it is then this
# configuration should be used for Cromwell. Similar changes will probably be needed for Nextflow and Step-Functions
#
###

set -e

function install_ebs_autoscale(){
  # install ebs-autoscale
  cd /opt && curl --silent --retry 5 --retry-connrefused "https://d52iwap9aqlil.cloudfront.net/aws-ebs-autoscale.tgz" -o "aws-ebs-autoscale.tgz" && tar -xzf aws-ebs-autoscale.tgz
  # mount an autoscalable drive at /var/lib/docker so that docker auto expands
  sh /opt/ebs-autoscale/bin/init-ebs-autoscale.sh /var/lib/docker /dev/sdc > /var/log/init-ebs-autoscale.log 2>&1
}

function write_docker_daemon(){
  if [ -e "/etc/docker/daemon.json" ];
  # If the file exsists then add or update the storage-driver kv pair to use btrfs, otherwise create the file
  then
    jq '. + {"storage-driver": "btrfs"}' < /etc/docker/daemon.json > /tmp/daemon.json && mv /tmp/daemon.json /etc/docker/daemon.json
  else
    jq -n '{"storage-driver": "btrfs"}' > /etc/docker/daemon.json
  fi
}

# install the fetch_and_run script to pull task execution scripts from s3
cd /usr/local/bin && curl --retry 5 --retry-connrefused "https://d52iwap9aqlil.cloudfront.net/fetch_and_run.sh" -o "fetch_and_run.sh" && chmod a+x ./fetch_and_run.sh

write_docker_daemon
install_ebs_autoscale
systemctl restart --no-block ecs

