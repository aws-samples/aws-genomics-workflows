#!/bin/bash
set -e

VERSION=${1:-release}

function develop() {
    # retrieve the current development version of amazon-ebs-autoscale
    # WARNING may not be fully tested or stable
    git clone https://github.com/awslabs/amazon-ebs-autoscale.git
    cd /opt/amazon-ebs-autoscale
    git checkout master
}

function latest() {
    # retrive the latest released version of amazon-ebs-autoscale
    # recommended if you want instances to stay up to date with upstream updates
    local ebs_autoscale_version=$(curl --silent "https://api.github.com/repos/awslabs/amazon-ebs-autoscale/releases/latest" | jq -r .tag_name)
    curl --silent -L \
        "https://github.com/awslabs/amazon-ebs-autoscale/archive/${ebs_autoscale_version}.tar.gz" \
        -o ./amazon-ebs-autoscale.tar.gz 

    tar -xzvf ./amazon-ebs-autoscale.tar.gz
    mv ./amazon-ebs-autoscale*/ ./amazon-ebs-autoscale
    echo $ebs_autoscale_version > ./amazon-ebs-autoscale/VERSION
}

function release() {
    # retrieve the version of amazon-ebs-autoscale concordant with the latest 
    # release of aws-genomics-workflows
    # recommended if you have no other way to get the amazon-ebs-autoscale code
    wget $artifactRootUrl/amazon-ebs-autoscale.tgz
    tar -xzf amazon-ebs-autoscale.tgz
}

function dist-release() {
    release
}

function install() {
    # this function expects the following environment variables
    #   EBS_AUTOSCALE_FILESYSTEM

    local filesystem=${EBS_AUTOSCALE_FILESYSTEM:-btrfs}
    local docker_storage_driver=btrfs

    case $filesystem in
        btrfs)
            docker_storage_driver=$filesystem
            ;;
        lvm.ext4)
            docker_storage_driver=overlay2
        *)
            echo "Unsupported filesystem - $filesystem"
            exit 1
    esac
    local docker_storage_options="s+OPTIONS=.*+OPTIONS=\"--storage-driver $docker_storage_driver\"+g"

    cp -au /var/lib/docker /var/lib/docker.bk
    rm -rf /var/lib/docker/*
    sh /opt/amazon-ebs-autoscale/install.sh -f $filesystem -m /var/lib/docker > /var/log/ebs-autoscale-install.log 2>&1
    sed -i $docker_storage_options /etc/sysconfig/docker-storage
    cp -au /var/lib/docker.bk/* /var/lib/docker

}


cd /opt
$VERSION

install