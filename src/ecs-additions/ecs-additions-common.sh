#!/bin/bash

# add fetch and run batch helper script
chmod a+x /opt/ecs-additions/fetch_and_run.sh
cp /opt/ecs-additions/fetch_and_run.sh /usr/local/bin

# add awscli-shim
mv /opt/aws-cli/bin /opt/aws-cli/dist
chmod a+x /opt/ecs-additions/awscli-shim.sh
mkdir /opt/aws-cli/bin
cp /opt/ecs-additions/awscli-shim.sh /opt/aws-cli/bin/aws                  # Used in Nextflow

# Remove current symlink
rm -f /usr/local/aws-cli/v2/current/bin/aws
cp /opt/ecs-additions/awscli-shim.sh /usr/local/aws-cli/v2/current/bin/aws # Used in Cromwell

# add 4GB of swap space
dd if=/dev/zero of=/swapfile bs=128M count=32
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
swapon -s
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
