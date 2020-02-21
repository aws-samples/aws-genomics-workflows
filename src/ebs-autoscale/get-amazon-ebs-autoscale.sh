#!/bin/bash

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
    EBS_AUTOSCALE_VERSION=$(curl --silent "https://api.github.com/repos/awslabs/amazon-ebs-autoscale/releases/latest" | jq -r .tag_name)
    curl --silent -L \
        "https://github.com/awslabs/amazon-ebs-autoscale/archive/${EBS_AUTOSCALE_VERSION}.tar.gz" \
        -o ./amazon-ebs-autoscale.tar.gz 

    tar -xzvf ./amazon-ebs-autoscale.tar.gz
    mv ./amazon-ebs-autoscale*/ ./amazon-ebs-autoscale
    echo $EBS_AUTOSCALE_VERSION > ./amazon-ebs-autoscale/VERSION
}

function release() {
    # retrieve the version of amazon-ebs-autoscale concordant with the latest 
    # release of aws-genomics-workflows
    # recommended if you have no other way to get the amazon-ebs-autoscale code
    wget $artifactRootUrl/amazon-ebs-autoscale.tgz
    tar -xzf amazon-ebs-autoscale.tgz
}

cd /opt
VERSION
