#!/bin/bash

# This shim is for using the AWS ClI v2 with containers that do not have full glibc
# it makes the shared libraries the AWS CLI v2 findable via LD_LIBRARY_PATH
#
# expect to be installed as /opt/aws-cli/bin/aws
# expect to actually call /opt/aws-cli/dist/aws
# expect that /opt/aws-cli is mapped to containers

BIN_DIR=`dirname $0`
DIST_DIR=`dirname $BIN_DIR`/dist
AWS=$DIST_DIR/aws

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$DIST_DIR

$AWS "$@"

