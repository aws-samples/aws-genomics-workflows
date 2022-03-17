#!/bin/bash

# ecs config options
# graceful shutdown of jobs on spot instances if spot is terminated
echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=true >> /etc/ecs/ecs.config
# cache already pulled container images and reduce network traffic
echo ECS_IMAGE_PULL_BEHAVIOR=prefer-cached >> /etc/ecs/ecs.config
# increase docker stop timeout so that containers can perform cleanup actions
echo ECS_CONTAINER_STOP_TIMEOUT=60 >> /etc/ecs/ecs.config
# This variable specifies how frequently the automated image cleanup process should check for images to delete. The default is every 30 minutes but you can reduce this period to as low as 10 minutes to remove images more frequently.
echo ECS_IMAGE_CLEANUP_INTERVAL=5m >> /etc/ecs/ecs.config
# This variable specifies the minimum amount of time between when an image was pulled and when it may become a candidate for removal. This is used to prevent cleaning up images that have just been pulled. The default is 1 hour.
echo ECS_IMAGE_MINIMUM_CLEANUP_AGE=60m >> /etc/ecs/ecs.config

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

# ensure that /usr/bin/aws points to the non-shimmed version
ln -sf /usr/local/aws-cli/v2/current/dist/aws /usr/bin/aws

# add 4GB of swap space
dd if=/dev/zero of=/swapfile bs=128M count=32
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
swapon -s
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
