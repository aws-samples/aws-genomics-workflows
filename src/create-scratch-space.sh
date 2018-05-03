if [  "$#" -lt 4 ]; then
  echo "USAGE: $0 <DEVICE NAME> <VOLUME GROUP NAME> <LOGICAL VOLUME NAME> <MOUNT POINT>"
  exit
fi
D=$1
VG=$2
LV=$3
MP=$4

## Example Code

# The code below creates a EBS volume and registers it as a new EXT4 filesystem.

# Create a initial EBS volume as Ext4 on LVM
A=({a..z})
Z=$(curl -s  http://169.254.169.254/latest/meta-data/placement/availability-zone )
R=$(echo $Z | sed -e 's/[a-z]$//')
I=$(curl -s  http://169.254.169.254/latest/meta-data/instance-id )
N=$(ls /dev/xvd* | grep -v -E '[0-9]$' | wc -l)
D="/dev/sd${A[$N]}"

# Create and attache the EBS Volume, also set it to delete on instance terminate
V=$(aws ec2 create-volume --region $R --availability-zone $Z --volume-type gp2 --size 10 --encrypted --query "VolumeId" | sed 's/\"//g' )

# await volume to become available
until [ "$(aws ec2 describe-volumes --volume-ids $V --region $R --query "Volumes[0].State" | sed -e 's/\"//g')" == "available" ]; do
  sleep 1
done

aws ec2 attach-volume --region $R --device $D --volume-id $V --instance-id $I
# change the DeleteOnTermination volume attribute to true
aws ec2 modify-instance-attribute --region $R --block-device-mappings "DeviceName=$D,Ebs={DeleteOnTermination=true,VolumeId=$V}" --instance-id $I

# wait until device is available to start adding to PV
until [ -b "$D" ]; do
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
