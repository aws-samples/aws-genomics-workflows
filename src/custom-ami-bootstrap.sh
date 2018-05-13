if [  "$#" -lt 3 ]; then
  echo "USAGE: $0 <VOLUME GROUP NAME> <LOGICAL VOLUME NAME> <MOUNT POINT>"
  exit
fi
VG=$2
LV=$3
MP=$4

# Create a initial EBS volume as Ext4 on LVM
A=({a..z})
Z=$(curl -s  http://169.254.169.254/latest/meta-data/placement/availability-zone )
R=$(echo $Z | sed -e 's/[a-z]$//')
I=$(curl -s  http://169.254.169.254/latest/meta-data/instance-id )
N=$(ls /dev/xvd* | grep -v -E '[0-9]$' | wc -l)
D="/dev/xvd${A[$N]}"

# Create and attache the EBS Volume, also set it to delete on instance terminate
V=$(aws ec2 create-volume --region $R --availability-zone $Z --volume-type gp2 --size 10 --encrypted --query "VolumeId" | sed 's/\"//g' )

# await volume to become available
until [ "$(aws ec2 describe-volumes --volume-ids $V --region $R --query "Volumes[0].State" | sed -e 's/\"//g')" == "available" ]; do
  echo "Volume $V not yet available"
  sleep 1
done

aws ec2 attach-volume --region $R --device $D --volume-id $V --instance-id $I
# change the DeleteOnTermination volume attribute to true
aws ec2 modify-instance-attribute --region $R --block-device-mappings "DeviceName=$D,Ebs={DeleteOnTermination=true,VolumeId=$V}" --instance-id $I

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
cp docker-ebs-autoscale/src/etc/init/docker-ebs-autoscale.conf /etc/init/docker-ebs-autoscale.conf
cp docker-ebs-autoscale/src/usr/local/bin/docker-ebs-autoscale /usr/local/bin/docker-ebs-autoscale
cp docker-ebs-autoscale/src/etc/logrotate.d/docker-ebs-autoscale /etc/logrotate.d/docker-ebs-autoscale
initctl reload-configuration
initctl start docker-ebs-autoscale
# remove the temp files (optional)
rm -fr docker-ebs-autoscale*

# pre-image creation ECS configuration changes
stop ecs
rm -rf /var/lib/ecs/data/ecs_agent_data.json

# update instance networking to allow containers to query for their Task IAM role credentials
sysctl -w net.ipv4.conf.all.route_localnet=1
iptables -t nat -A PREROUTING -p tcp -d 169.254.170.2 --dport 80 -j DNAT --to-destination 127.0.0.1:51679
iptables -t nat -A OUTPUT -d 169.254.170.2 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 51679
service iptables save

# clean up repository caches
yum clean all
