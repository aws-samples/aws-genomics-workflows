#!/usr/bin/env python
from __future__ import print_function
import glob, re, os, sys, time
import boto3
import urllib
import argparse

## TODO: CLI arguments
parameters = argparse.ArgumentParser(description="Create a new EBS Volume and attach it to the current instance")
parameters.add_argument("-s","--size", type=int, required=True)
parameters.add_argument("-t","--type", type=str, default="gp2")
parameters.add_argument("-e","--encrypted", type=bool, default=True)

def device_exists(path):
    try:
        return os.path.stat.S_ISBLK(os.stat(path).st_mode)
    except:
        return False

alphabet = []
for letter in range(97,123):
    alphabet.append(chr(letter))

def detect_devices():
    devices = []
    for device in glob.glob('/dev/sd*'):
        devices.append(device)
    return devices

def get_next_logical_device():
    d = "/dev/sd{0}".format( alphabet[len(detect_devices())] )
    return d

def get_metadata(key):
    return urllib.urlopen(("/").join(['http://169.254.169.254/latest/meta-data', key])).read()


# create a EBS volume
def create_and_attach_volume(size=10, vol_type="gp2", encrypted=True):
    instance_id  = get_metadata("instance-id")
    availability_zone = get_metadata("placement/availability-zone")
    region =  availability_zone[0:-1]
    ec2 = boto3.resource("ec2", region_name=region)
    instance = ec2.Instance(instance_id)
    volume = ec2.create_volume(
        AvailabilityZone=availability_zone,
        Encrypted=encrypted,
        VolumeType=vol_type,
        Size=size
    )
    while True:
        volume.reload()
        if volume.state == "available":
            break
        else:
            time.sleep(1)

    device = get_next_logical_device()
    instance.attach_volume(
        VolumeId=volume.volume_id,
        Device=device
    )
    # wait until device exists
    while True:
        if device_exists(device):
            break
        else:
            time.sleep(1)
    instance.modify_attribute(
        Attribute="blockDeviceMapping",
        BlockDeviceMappings=[{"DeviceName": device,
            "Ebs": {"DeleteOnTermination":True,"VolumeId":volume.volume_id}
        }]
    )
    return device

if __name__ == '__main__':
    args = parameters.parse_args()
    print(create_and_attach_volume(args.size), end='')
    sys.stdout.flush()
