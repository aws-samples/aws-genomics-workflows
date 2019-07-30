#!/bin/bash

set -e

bash _scripts/make-artifacts.sh
mkdocs build

ASSET_BUCKET=s3://aws-genomics-workflows
ASSET_STAGE=${1:-production}

function artifacts() {
    IFS=""
    S3_URI_PARTS=($ASSET_BUCKET $ASSET_STAGE_PATH "artifacts")
    S3_URI_PARTS=(${S3_URI_PARTS[@]})
    S3_URI=$(printf '/%s' "${S3_URI_PARTS[@]%/}")

    echo "publishing artifacts: $S3_URI"
    aws s3 sync \
        --profile asset-publisher \
        --acl public-read \
        --delete \
        ./artifacts \
        $S3_URI
}

function templates() {
    IFS=""
    S3_URI_PARTS=($ASSET_BUCKET $ASSET_STAGE_PATH "artifacts")
    S3_URI_PARTS=(${S3_URI_PARTS[@]})
    S3_URI=$(printf '/%s' "${S3_URI_PARTS[@]%/}")
    
    echo "publishing templates: $S3_URI"
    aws s3 sync \
        --profile asset-publisher \
        --acl public-read \
        --delete \
        --metadata commit=$(git rev-parse HEAD) \
        ./src/templates \
        $S3_URI
}

function site() {
    echo "publishing site"
    aws s3 sync \
        --acl public-read \
        --delete \
        ./site \
        s3://docs.opendata.aws/genomics-workflows
}

function all() {
    artifacts
    templates
    site
}

case $STAGE in
    production)
        ASSET_STAGE_PATH=""
        all
        ;;
    test)
        ASSET_STAGE_PATH="test"
        artifacts
        templates
        ;;
    *)
        echo "unsupported staging level"
        exit 1
esac
