#!/bin/bash

CWD=`pwd`
ARTIFACT_PATH=${CWD}/artifacts
SOURCE_PATH=${CWD}/src


if [ ! -d ${ARTIFACT_PATH} ];
then
    mkdir ${ARTIFACT_PATH}
fi


if [ -f ${ARTIFACT_PATH}/aws-ebs-autoscale.tgz ];
then
    echo "asset [ebs-autoscale]: removing previous build:"
    rm -v ${ARTIFACT_PATH}/aws-ebs-autoscale.tgz
fi

if [ -f ${ARTIFACT_PATH}/aws-ecs-additions.tgz ];
then
    echo "asset [ecs-aditions]: removing previous build:"
    rm -v ${ARTIFACT_PATH}/aws-ecs-additions.tgz
fi


echo "repackaging:"

# package ebs-autoscale
# combines the latest release of amazon-ebs-autoscale with compatibility shim
# scripts in ./ebs-autoscale/
cd ${SOURCE_PATH}
EBS_AUTOSCALE_VERSION=$(curl --silent "https://api.github.com/repos/awslabs/amazon-ebs-autoscale/releases/latest" | jq -r .tag_name)
curl --silent -L \
    "https://github.com/awslabs/amazon-ebs-autoscale/archive/${EBS_AUTOSCALE_VERSION}.tar.gz" \
    -o ./amazon-ebs-autoscale.tar.gz 

tar -xzvf ./amazon-ebs-autoscale.tar.gz
mv ./amazon-ebs-autoscale*/ ./amazon-ebs-autoscale
echo $EBS_AUTOSCALE_VERSION > ./amazon-ebs-autoscale/VERSION
cp -Rfv ./amazon-ebs-autoscale/* ./ebs-autoscale/

tar -czvf ${ARTIFACT_PATH}/aws-ebs-autoscale.tgz ./ebs-autoscale/

# add a copy of the release tarball for naming consistency
tar -czvf ${ARTIFACT_PATH}/amazon-ebs-autoscale.tgz ./amazon-ebs-autoscale

# add a retrieval script
cp -vf ./ebs-autoscale/get-amazon-ebs-autoscale.sh ${ARTIFACT_PATH}

# package ecs-additions
cd ${SOURCE_PATH}
tar -czvf ${ARTIFACT_PATH}/aws-ecs-additions.tgz ./ecs-additions/

cd ${CWD}

