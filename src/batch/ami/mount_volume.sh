#!/usr/bin/env bash

sudo yum -y update
sudo parted /dev/sdb mklabel gpt
sudo parted /dev/sdb mkpart primary 0% 100%
sudo mkfs -t ext4 /dev/sdb1
sudo mkdir /docker_scratch
sudo echo -e '/dev/sdb1\t/docker_scratch\text4\tdefaults\t0\t0' | sudo tee -a /etc/fstab
sudo mount -a
