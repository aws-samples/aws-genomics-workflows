#!/bin/bash

# this is a shim for backwards compatibility for releases <2.6.0
# old steps:
# - cd /opt && wget $artifactRootUrl/aws-ebs-autoscale.tgz && tar -xzf aws-ebs-autoscale.tgz
# - sh /opt/ebs-autoscale/bin/init-ebs-autoscale.sh $scratchPath /dev/sdc  2>&1 > /var/log/init-ebs-autoscale.log
sh /opt/a*-ebs-autoscale/install.sh $@