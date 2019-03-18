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
cd ${SOURCE_PATH}
tar -czvf ${ARTIFACT_PATH}/aws-ebs-autoscale.tgz ./ebs-autoscale/
tar -czvf ${ARTIFACT_PATH}/aws-ecs-additions.tgz ./ecs-additions/


cd ${CWD}

