#!/bin/bash

CWD=`pwd`
SOURCE_PATH=${CWD}/src
DIST_PATH=${CWD}/dist

TEMP_PATH=${DIST_PATH}/tmp
ARTIFACT_PATH=${DIST_PATH}/artifacts
TEMPLATES_PATH=${DIST_PATH}/templates

if [ ! -d $DIST_PATH ]; then
    mkdir -p $DIST_PATH
fi

cd $DIST_PATH

# clean up previous dist build
echo "removing previous dist"
rm -rf ./*

for d in $TEMP_PATH $ARTIFACT_PATH $TEMPLATES_PATH;
do
    if [ ! -d $d ];
    then
        echo "creating $d"
        mkdir -p $d
    fi
done

# package ebs-autoscale
# combines the latest release of amazon-ebs-autoscale with compatibility shim
# scripts in ./ebs-autoscale/
echo "packaging amazon-ebs-autoscale"
cd ${TEMP_PATH}

EBS_AUTOSCALE_VERSION=$(curl --silent "https://api.github.com/repos/awslabs/amazon-ebs-autoscale/releases/latest" | jq -r .tag_name)
curl --silent -L \
    "https://github.com/awslabs/amazon-ebs-autoscale/archive/${EBS_AUTOSCALE_VERSION}.tar.gz" \
    -o ./amazon-ebs-autoscale.tar.gz 

tar -xzvf ./amazon-ebs-autoscale.tar.gz
mv ./amazon-ebs-autoscale*/ ./amazon-ebs-autoscale
echo $EBS_AUTOSCALE_VERSION > ./amazon-ebs-autoscale/VERSION

cp -Rfv $SOURCE_PATH/ebs-autoscale .
cp -Rfv ./amazon-ebs-autoscale/* ./ebs-autoscale/

tar -czvf ${ARTIFACT_PATH}/aws-ebs-autoscale.tgz ./ebs-autoscale/

# add a copy of the release tarball for naming consistency
tar -czvf ${ARTIFACT_PATH}/amazon-ebs-autoscale.tgz ./amazon-ebs-autoscale

# add a retrieval script
cp -vf ${SOURCE_PATH}/ebs-autoscale/get-amazon-ebs-autoscale.sh ${ARTIFACT_PATH}

# package crhelper lambda(s)
cd ${SOURCE_PATH}/lambda
for fn in `ls .`; do
    echo "packaging crhelper lambda $fn"
    mkdir -p ${TEMP_PATH}/lambda/$fn
    cp -Rv ${SOURCE_PATH}/lambda/$fn/. ${TEMP_PATH}/lambda/$fn

    cd ${TEMP_PATH}/lambda/$fn
    pip install -t . -r requirements.txt
    zip -r -v $ARTIFACT_PATH/lambda-$fn.zip .
done


# package ecs-additions
echo "packaging ecs-additions"

cd ${TEMP_PATH}
mkdir -p ${TEMP_PATH}/ecs-additions
cp -Rv ${SOURCE_PATH}/ecs-additions/. ${TEMP_PATH}/ecs-additions

# add the amazon-ebs-autoscale retrieval script to additions
cp -v ${SOURCE_PATH}/ebs-autoscale/get-amazon-ebs-autoscale.sh ${TEMP_PATH}/ecs-additions

# keep tarball for backwards compatibilty
cd ${TEMP_PATH}
tar -czvf ${ARTIFACT_PATH}/aws-ecs-additions.tgz ./ecs-additions/

# zip file for codecommit repo
cd ${TEMP_PATH}/ecs-additions/
zip -r -v ${ARTIFACT_PATH}/aws-ecs-additions.zip ./*


# package container code
echo "packaging container definitions"
cd $SOURCE_PATH/containers
zip -r -v $ARTIFACT_PATH/containers.zip ./*


# add templates to dist
echo "copying cloudformation templates"
cp -Rv $SOURCE_PATH/templates/. $TEMPLATES_PATH


# cleanup
echo "removing temp files"
rm -rvf $TEMP_PATH

cd $CWD