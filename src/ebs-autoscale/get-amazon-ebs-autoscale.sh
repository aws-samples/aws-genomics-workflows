#!/bin/bash
set -e

VERSION=${1:-release}
ARTIFACT_ROOT_URL=$2
FILESYSTEM=${3:-btrfs}

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

    if [[ "$ARTIFACT_ROOT_URL" =~ ^http.* ]]; then
        wget $ARTIFACT_ROOT_URL/amazon-ebs-autoscale.tgz
    elif [[ "$ARTIFACT_ROOT_URL" =~ ^s3.* ]]; then
        aws s3 cp --no-progress $ARTIFACT_ROOT_URL/amazon-ebs-autoscale.tgz .
    else
        echo "unrecognized protocol in $ARTIFACT_ROOT_URL"
        exit 1
    fi

    tar -xzf amazon-ebs-autoscale.tgz
}

function dist_release() {
    # alias for release() for now
    # eventually, these may do different things
    release
}

function install() {
    # this function expects the following environment variables
    #   EBS_AUTOSCALE_FILESYSTEM

    local filesystem=${1:-btrfs}
    local docker_storage_driver=btrfs

    case $filesystem in
        btrfs)
            docker_storage_driver=$filesystem
            ;;
        lvm.ext4)
            docker_storage_driver=overlay2
            ;;
        *)
            echo "Unsupported filesystem - $filesystem"
            exit 1
    esac
    local docker_storage_options="DOCKER_STORAGE_OPTIONS=\"--storage-driver $docker_storage_driver\""
    
    cp -au /var/lib/docker /var/lib/docker.bk
    rm -rf /var/lib/docker/*
    sh /opt/amazon-ebs-autoscale/install.sh -f $filesystem -m /var/lib/docker > /var/log/ebs-autoscale-install.log 2>&1

    awk -v docker_storage_options="$docker_storage_options" \
        '{ sub(/DOCKER_STORAGE_OPTIONS=.*/, docker_storage_options); print }' \
        /etc/sysconfig/docker-storage \
        > /opt/amazon-ebs-autoscale/docker-storage
    mv -f /opt/amazon-ebs-autoscale/docker-storage /etc/sysconfig/docker-storage

    cp -au /var/lib/docker.bk/* /var/lib/docker

}


cd /opt
$VERSION

install $FILESYSTEM