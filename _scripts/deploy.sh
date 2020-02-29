#!/bin/bash

set -e

bash _scripts/make-artifacts.sh
mkdocs build

ASSET_BUCKET=s3://aws-genomics-workflows
ASSET_STAGE=${1:-production}


function s3_uri() {
    BUCKET=$1
    shift

    IFS=""
    PREFIX_PARTS=("$@")
    PREFIX_PARTS=(${PREFIX_PARTS[@]})
    PREFIX=$(printf '/%s' "${PREFIX_PARTS[@]%/}")
    
    echo "${BUCKET%/}/${PREFIX:1}"
}


function artifacts() {
    # root level is always "latest"
    S3_URI=$(s3_uri $ASSET_BUCKET $ASSET_STAGE_PATH "artifacts")

    echo "publishing artifacts: $S3_URI"
    aws s3 sync \
        --profile asset-publisher \
        --acl public-read \
        --delete \
        ./artifacts \
        $S3_URI
    
    if [[ $USE_RELEASE_TAG && ! -z "$TRAVIS_TAG" ]]; then
        S3_URI=$(s3_uri $ASSET_BUCKET $ASSET_STAGE_PATH $TRAVIS_TAG "artifacts")

        echo "publishing artifacts: $S3_URI"
        aws s3 sync \
            --profile asset-publisher \
            --acl public-read \
            --delete \
            ./artifacts \
            $S3_URI
    fi
}

function templates() {
    # root level is always "latest"
    S3_URI=$(s3_uri $ASSET_BUCKET $ASSET_STAGE_PATH "templates")

    echo "publishing templates: $S3_URI"
    aws s3 sync \
        --profile asset-publisher \
        --acl public-read \
        --delete \
        --metadata commit=$(git rev-parse HEAD) \
        ./src/templates \
        $S3_URI
    
    if [[ $USE_RELEASE_TAG && ! -z "$TRAVIS_TAG" ]]; then
        S3_URI=$(s3_uri $ASSET_BUCKET $ASSET_STAGE_PATH $TRAVIS_TAG "templates")

        echo "publishing templates: $S3_URI"
        aws s3 sync \
            --profile asset-publisher \
            --acl public-read \
            --delete \
            --metadata commit=$(git rev-parse HEAD) \
            ./src/templates \
            $S3_URI
    fi
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

echo "DEPLOYMENT STAGE: $ASSET_STAGE"
case $ASSET_STAGE in
    production)
        ASSET_STAGE_PATH=""
        USE_RELEASE_TAG=1
        all
        ;;
    test)
        ASSET_STAGE_PATH="test"
        artifacts
        templates
        ;;
    *)
        echo "unsupported staging level - $ASSET_STAGE"
        exit 1
esac
