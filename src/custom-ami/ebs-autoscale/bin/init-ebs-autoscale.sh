#!/bin/sh

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
if [ -z "${DV}" ] || [ ! -b "${DV}"]; then
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
