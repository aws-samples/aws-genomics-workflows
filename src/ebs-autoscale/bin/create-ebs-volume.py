#!/usr/bin/env python
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

from __future__ import print_function
import glob, re, os, sys, time
import urllib
import argparse

import boto3
from botocore.exceptions import ClientError

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
# Use letters b..z
for letter in range(98,123):
    alphabet.append(chr(letter))

def detect_devices():
    devices = []
    for device in glob.glob('/dev/sd*'):
        devices.append(device)
    return devices

def get_next_logical_device():
    devices = detect_devices()
    for letter in alphabet:
        d = "/dev/sd{0}".format(letter)
        if d not in devices:
            return d
    return None

def get_metadata(key):
    return urllib.urlopen(("/").join(['http://169.254.169.254/latest/meta-data', key])).read()


# create a EBS volume
def create_and_attach_volume(size=10, vol_type="gp2", encrypted=True, max_attached_volumes=16, max_created_volumes=256):
    instance_id  = get_metadata("instance-id")
    availability_zone = get_metadata("placement/availability-zone")
    region =  availability_zone[0:-1]
    session = boto3.Session(region_name=region)

    ec2 = session.resource("ec2")
    client = session.client("ec2")
    instance = ec2.Instance(instance_id)

    # TODO: put a limit on the number of created volumes from this instance
    # use tagging by instance-id for filtering

    # limit the number of volumes that can be attached to the instance
    attached_volumes = [v.id for v in instance.volumes.all()]
    if len(attached_volumes) > max_attached_volumes:
        raise RuntimeError(
            "maximum number of attached volumes reached ({})".format(max_attached_volumes)
        )

    device = get_next_logical_device()
    if not device:
        raise RuntimeError(
            "could not find unused device"
        )

    # Attempt to create the volume
    # A ClientError is thrown if there are insufficient permissions or if
    # service limits are reached (e.g. hitting the limit for a storage class in a region)
    # It's ok for this error to be uncaught.
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

    # Need to assure that the created volume is successfully attached to be
    # cost efficient.  If attachment fails, delete the volume.
    try:
        instance.attach_volume(
            VolumeId=volume.volume_id,
            Device=device
        )
    except ClientError as e:
        client.delete_volume(VolumeId=volume.volume_id)
        raise e

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
