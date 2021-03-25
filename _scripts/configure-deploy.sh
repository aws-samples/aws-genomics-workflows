#!/bin/bash

# Create a default ~/.aws/configure file for Travis testing

set -e

# This script expects the following environment variable(s)
# ASSET_ROLE_ARN: the AWS role ARN that is used to publish assets

usage() {
    cat <<EOM
    Usage:
    $(basename $0) [--clobber]

    --clobber  Overwrite ~/.aws/configure file without asking
EOM
}

CLOBBER=''
PARAMS=""
while (( "$#" )); do
    case "$1" in
        --clobber)
            CLOBBER=1
            shift
            ;;
        --help)
            usage
            exit 0
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

if [ -z $CLOBBER ]; then
    while true; do
        read -p "Overwrite ~/.aws/config file [y/n]? " yn
        case $yn in
            [Yy]* ) CLOBBER=1; break;;
            [Nn]* ) echo "Exiting"; exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

mkdir -p $HOME/.aws
cat << EOF > $HOME/.aws/config
[default]
region = us-east-1
output = json

[profile asset-publisher]
region = us-east-1
role_arn = ${ASSET_ROLE_ARN}
credential_source = Environment
EOF

cat $HOME/.aws/config