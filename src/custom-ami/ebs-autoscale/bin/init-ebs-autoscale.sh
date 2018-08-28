#!/bin/sh
# Copyright 2018 Amazon.com, Inc. or its affiliates.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#
#  1. Redistributions of source code must retain the above copyright notice,
#  this list of conditions and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright
#  notice, this list of conditions and the following disclaimer in the
#  documentation and/or other materials provided with the distribution.
#
#  3. Neither the name of the copyright holder nor the names of its
#  contributors may be used to endorse or promote products derived from
#  this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
#  BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
#  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
#  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
#  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
#  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
#  IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.

function printUsage() {
  #statements
  echo "USAGE: $0 <MOUNT POINT> [<DEVICE>]"
}

if [ "$#" -lt "1" ]; then
  printUsage
  exit 1
fi


MP=$1
DV=$2

AZ=$(curl -s  http://169.254.169.254/latest/meta-data/placement/availability-zone/)
RG=$(echo ${AZ} | sed -e 's/[a-z]$//')
IN=$(curl -s  http://169.254.169.254/latest/meta-data/instance-id)
BASEDIR=$(dirname $0)

# copy the binaries to /usr/local/bin
cp ${BASEDIR}/{create-ebs-volume.py,ebs-autoscale} /usr/local/bin/

# If a device is not given, or if the device is not valid
# create a new 20GB volume
if [ -z "${DV}" ] || [ ! -b "${DV}" ]; then
  DV=$(create-ebs-volume.py --size 20)
fi

# create the BTRFS filesystem
mkfs.btrfs -f -d single $DV

if [ -e $MP ] && ! [ -d $MP ]; then
  echo "ERR: $MP exists but is not a directory."
  exit 1
elif ! [ -e $MP ]; then
  mkdir -p $MP
fi
mount $DV $MP

echo -e "${DV}\t${MP}\tbtrfs\tdefaults\t0\t0" |  tee -a /etc/fstab

# go to the template directory
cd ${BASEDIR}/../templates

# install the upstart config
sed -e "s#YOUR_MOUNTPOINT#${MP}#" ebs-autoscale.conf.template > /etc/init/ebs-autoscale.conf

# install the logrotate config
cp ebs-autoscale.logrotate /etc/logrotate.d/ebs-autoscale

# Register the ebs-autoscale upstart conf and start the service
initctl reload-configuration
initctl start ebs-autoscale
