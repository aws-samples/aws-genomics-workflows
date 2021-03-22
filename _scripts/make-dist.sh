#!/bin/bash

# make-dist.sh: Create distribution artifacts
# This script is expected to be in a subdirectory of the top-level directory
# It accesses the subdirectory 'src', and creates a subdirectory 'dist', in the top-level directory:
#    .
#    |-_scripts
#    |---make-dist.sh
#    |-dist
#    |-src


VERBOSE=""
PARAMS=""
while (( "$#" )); do
    case "$1" in
        --verbose)
            VERBOSE='-v'
            shift
            ;;
        --) # end optional argument parsing
            shift
            break
            ;;
        -*|--*=)
            echo "Error: unsupported argument $1" >&2
            exit 1
            ;;
        *) # positional agruments
            PARAMS="$PARAMS $1"
            shift
            ;;
    esac
done
eval set -- "$PARAMS"

echo "checking for dependencies"

DEPENDENCIES=$(cat <<EOF
curl
jq
pip
tar
zip
EOF
)

for dep in $DEPENDENCIES; do
    dep_path=`command -v $dep`
    if [[ $dep_path ]]; then
        echo "requirement '$dep' found ($dep_path). ok"
    else
        echo "requirement '$dep' not found. aborting"
        exit 1
    fi
done

# fail on any error
set -e

CWD=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
INSTALL_DIR=$(dirname $DIR)
SOURCE_PATH=$INSTALL_DIR/src
DIST_PATH=$INSTALL_DIR/dist

TEMP_PATH=$DIST_PATH/tmp
ARTIFACT_PATH=$DIST_PATH/artifacts
TEMPLATES_PATH=$DIST_PATH/templates

if [ ! -d $DIST_PATH ]; then
    mkdir -p $DIST_PATH
fi

cd $DIST_PATH

# clean up previous dist build
echo "removing previous dist in $DIST_PATH"
[ ! -z $DIR ] && rm -rf $DIST_PATH/*

for d in $TEMP_PATH $ARTIFACT_PATH $TEMPLATES_PATH; do
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
cd $TEMP_PATH

RESPONSE=$(curl --silent "https://api.github.com/repos/awslabs/amazon-ebs-autoscale/releases/latest")
EBS_AUTOSCALE_VERSION=$(echo $RESPONSE | jq -r .tag_name)
if [[ $EBS_AUTOSCALE_VERSION = 'null' ]]; then
    echo "ERROR: $RESPONSE"
    exit 1
fi
curl --silent -L \
    "https://github.com/awslabs/amazon-ebs-autoscale/archive/${EBS_AUTOSCALE_VERSION}.tar.gz" \
    -o ./amazon-ebs-autoscale.tar.gz 

echo "copying $(tar -tzf ./amazon-ebs-autoscale.tar.gz | wc -l) files from ebs-autoscale $EBS_AUTOSCALE_VERSION into tmp/amazon-ebs-autoscale/"
tar $VERBOSE -xzf ./amazon-ebs-autoscale.tar.gz
mv ./amazon-ebs-autoscale*/ ./amazon-ebs-autoscale
echo $EBS_AUTOSCALE_VERSION > ./amazon-ebs-autoscale/VERSION

echo "copying src/ebs-autoscale with $(find $SOURCE_PATH/ebs-autoscale/ -type f | wc -l) files to tmp/"
cp $VERBOSE -Rf $SOURCE_PATH/ebs-autoscale .
echo "copying $(find amazon-ebs-autoscale -type f | wc -l) files from tmp/amazon-ebs-autoscale/ to tmp/ebs-autoscale/"
cp $VERBOSE -Rf ./amazon-ebs-autoscale/* ./ebs-autoscale/
echo "creating artifacts/aws-ebs-autoscale.tgz with $(find ./ebs-autoscale/ -type f | wc -l) files from tmp/ebs-autoscale/"
tar $VERBOSE -czf $ARTIFACT_PATH/aws-ebs-autoscale.tgz ./ebs-autoscale/

# add a copy of the release tarball for naming consistency
echo "creating artifacts/amazon-ebs-autoscale.tgz with $(find ./amazon-ebs-autoscale/ -type f | wc -l) files from tmp/amazon-ebs-autoscale/"
tar $VERBOSE -czf $ARTIFACT_PATH/amazon-ebs-autoscale.tgz ./amazon-ebs-autoscale

# add a retrieval script
cp $VERBOSE -f $SOURCE_PATH/ebs-autoscale/get-amazon-ebs-autoscale.sh $ARTIFACT_PATH

# package crhelper lambda(s)
cd $SOURCE_PATH/lambda
for fn in `ls .`; do
    echo "packaging crhelper lambda $fn"
    mkdir -p $TEMP_PATH/lambda/$fn
    cp $VERBOSE -R $SOURCE_PATH/lambda/$fn/. $TEMP_PATH/lambda/$fn

    cd $TEMP_PATH/lambda/$fn
    [ -z $VERBOSE ] && P_QUIET='--quiet' || P_QUIET=''
    pip $P_QUIET install -t . -r requirements.txt
    echo "creating artifacts/lambda-${fn}.zip with $(find . -type f | wc -l) files"
    [ -z $VERBOSE ] && Z_QUIET='-q' || Z_QUIET=''
    zip $Z_QUIET -r $ARTIFACT_PATH/lambda-$fn.zip .
done

# package ecs-additions
echo "packaging ecs-additions"

cd $TEMP_PATH
mkdir -p $TEMP_PATH/ecs-additions
cp $VERBOSE -R $SOURCE_PATH/ecs-additions/. $TEMP_PATH/ecs-additions

# add the amazon-ebs-autoscale retrieval script to additions
cp $VERBOSE $SOURCE_PATH/ebs-autoscale/get-amazon-ebs-autoscale.sh $TEMP_PATH/ecs-additions

# keep tarball for backwards compatibilty
cd $TEMP_PATH
tar $VERBOSE -czf $ARTIFACT_PATH/aws-ecs-additions.tgz ./ecs-additions/

# zip file for codecommit repo
cd $TEMP_PATH/ecs-additions/
zip $Z_QUIET -r $ARTIFACT_PATH/aws-ecs-additions.zip ./*


# package container code
echo "packaging container definitions with $(find $SOURCE_PATH/containers -type f | wc -l) files"
cd $SOURCE_PATH/containers
zip $Z_QUIET -r $ARTIFACT_PATH/containers.zip ./*


# add templates to dist
echo "copying $(find $SOURCE_PATH/templates/ -type f | wc -l) cloudformation templates"
cp $VERBOSE -R $SOURCE_PATH/templates/. $TEMPLATES_PATH


# cleanup
echo "removing temp files"
rm -rf $TEMP_PATH

cd $CWD