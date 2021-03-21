#!/bin/bash

# deploy.sh: Create and deploy distribution artifacts

set -e

SITE_BUCKET=s3://docs.opendata.aws/genomics-workflows
ASSET_BUCKET=s3://aws-genomics-workflows
ASSET_STAGE=test
ASSET_PROFILE=asset-publisher
DEPLOY_REGION=us-east-1

VERBOSE=''
PARAMS=""
while (( "$#" )); do
    case "$1" in
        --site-bucket)
            SITE_BUCKET=$2
            shift 2
            ;;
        --asset-bucket)
            ASSET_BUCKET=$2
            shift 2
            ;;
        --asset-profile)
            ASSET_PROFILE=$2
            shift 2
            ;;
        --deploy-region)
            DEPLOY_REGION=$2
            shift 2
            ;;
        --verbose)
            VERBOSE='--verbose'
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

ASSET_STAGE=${1:-$ASSET_STAGE}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
bash ${DIR}/make-dist.sh $VERBOSE

function s3_uri() {
    BUCKET=$1
    shift

    IFS=""
    PREFIX_PARTS=("$@")
    PREFIX_PARTS=(${PREFIX_PARTS[@]})
    PREFIX=$(printf '/%s' "${PREFIX_PARTS[@]%/}")
    
    echo "${BUCKET%/}/${PREFIX:1}"
}

function s3_sync() {
    local source=$1
    local destination=$2

    echo "syncing ..."
    echo "   from: $source"
    echo "     to: $destination"
    cmd="aws s3 sync \
        --profile $ASSET_PROFILE \
        --region $DEPLOY_REGION \
        --delete \
        --metadata commit=$(git rev-parse HEAD) \
        $source \
        $destination"
    echo $cmd
    eval $cmd
    exit
}

function publish() {
    local source=$1
    local destination=$2

    echo "publish(source: $source, destintation: $destination)"
    if [[ $USE_RELEASE_TAG && ! -z "$TRAVIS_TAG" ]]; then
        # create explicit pinned versions "latest" and TRAVIS_TAG
        # pin the TRAVIS_TAG first, since the files are modified inplace
        # "latest" will inherit the TRAVIS_TAG value
        echo "PINNED VERSION: $TRAVIS_TAG"
        for version in $TRAVIS_TAG latest; do
            S3_URI=$(s3_uri $ASSET_BUCKET $ASSET_STAGE_PATH $version $destination)

            if [[ "$destination" == "templates" ]]; then
                # pin distribution template and artifact paths in cfn templates
                pin_version $version templates $source
                pin_version $version artifacts $source
            fi

            s3_sync $source $S3_URI
        done
    elif [[ $ASSET_STAGE == "test" ]]; then
        echo "PINNED VERSION: $ASSET_STAGE"
        version=$ASSET_STAGE
        S3_URI=$(s3_uri $ASSET_BUCKET $ASSET_STAGE_PATH $destination)

        if [[ "$destination" == "templates" ]]; then
            # pin distribution template and artifact paths in cfn templates
            pin_version $version templates $source
            pin_version $version artifacts $source
        fi

        s3_sync $source $S3_URI
    else
        echo "unknown publish target"
        exit 1
    fi

}


function pin_version() {
    # locates parameters in cfn templates files in {folder} that need to be version pinned
    # using the locator pattern: "{asset}\s{2}# dist: {action}"
    # replaces the locator pattern with: "{version}/{asset}  #"
    local version=$1
    local asset=$2
    local folder=$3

    echo "PINNING VERSIONS"
    for file in `grep -irl "$asset  # dist: pin_version" $folder`; do
        echo "pinning '$asset' as '$version/$asset' in '$file'"
        sed -i'' -e "s|$asset  # dist: pin_version|$version/$asset  #|g" $file
    done
}


function artifacts() {

    publish ./dist/artifacts artifacts

}


function templates() {

    publish ./dist/templates templates

}


function site() {
    echo "building site"
    if [[ ! `command -v mkdocs` ]]; then
        echo "requirement mkdocs not found. aborting"
        exit 1
    fi
    mkdocs build

    echo "publishing site"
    aws s3 sync \
        --region $DEPLOY_REGION \
        --acl public-read \
        --delete \
        --metadata commit=$(git rev-parse HEAD) \
        ./site \
        $SITE_BUCKET
}


function all() {
    artifacts
    templates
    site
}

# Add 's3://' when missing from bucket names
for bucketname in ASSET_BUCKET SITE_BUCKET; do
    if [[ ! $(echo ${!bucketname} | grep 's3://') ]]; then
        newname="s3://${!bucketname}";
        eval $bucketname=\$newname;
    fi
done

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
