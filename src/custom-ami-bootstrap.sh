if [  "$#" -lt 4 ]; then
  echo "USAGE: $0 <DEVICE NAME> <VOLUME GROUP NAME> <LOGICAL VOLUME NAME> <MOUNT POINT>"
  exit
fi
D=$1
VG=$2
LV=$3
MP=$4

# if docker-ebs-autoscale exe exists, skip bootstrap
if [ -e /usr/local/bin/docker-ebs-autoscale ]; then
  exit 0
fi

# Instance information
Z=$(curl -s  http://169.254.169.254/latest/meta-data/placement/availability-zone )
R=$(echo $Z | sed -e 's/[a-z]$//')
I=$(curl -s  http://169.254.169.254/latest/meta-data/instance-id )

# wait until device is available to start adding to PV
until [ -b "$D" ]; do
  echo "Volume $D not yet available"
  sleep 1
done

# Register the physical volume
pvcreate $D
# create the new volume group
vgcreate ${VG} $D
# get free extents in volume group
E=$(vgdisplay ${VG} |grep "Free" | awk '{print $5}')

# create the logical volume
lvcreate -l $E  -n ${LV} ${VG}

#make the filesystem and mount it
mkfs.ext4 /dev/${VG}/${LV}
mkdir ${MP}
mount /dev/${VG}/${LV} ${MP}
echo -e "/dev/${VG}/${LV}\t${MP}\text4\tdefaults\t0\t0" |  tee -a /etc/fstab

# download and install the /docker_scratch autoscale service
cd /tmp
curl -O https://cromwell-aws-batch.s3.amazonaws.com/files/docker-ebs-autoscale.tar.gz
tar -xzf docker-ebs-autoscale.tar.gz
cp docker-ebs-autoscale/src/etc/init/docker-ebs-autoscale.conf /etc/init/
cp docker-ebs-autoscale/src/usr/local/bin/* /usr/local/bin/
cp docker-ebs-autoscale/src/etc/logrotate.d/docker-ebs-autoscale /etc/logrotate.d/
initctl reload-configuration
initctl start docker-ebs-autoscale
# remove the temp files (optional)
rm -fr docker-ebs-autoscale*

# update instance networking to allow containers to query for their Task IAM role credentials
sysctl -w net.ipv4.conf.all.route_localnet=1
iptables -t nat -A PREROUTING -p tcp -d 169.254.170.2 --dport 80 -j DNAT --to-destination 127.0.0.1:51679
iptables -t nat -A OUTPUT -d 169.254.170.2 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 51679
service iptables save

# clean up repository caches
yum clean all
