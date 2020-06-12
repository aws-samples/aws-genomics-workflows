#!/bin/bash

set -e

bash _scripts/make-dist.sh
mkdocs build

ASSET_BUCKET=s3://aws-genomics-workflows
ASSET_STAGE=${1:-production}

PARAMS=""
while (( "$#" )); do
    case "$1" in
        --bucket)
            ASSET_BUCKET=$2
            shift 2
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

function s3_uri() {
    BUCKET=$1
    shift

    IFS=""
    PREFIX_PARTS=("$@")
    PREFIX_PARTS=(${PREFIX_PARTS[@]})
    PREFIX=$(printf '/%s' "${PREFIX_PARTS[@]%/}")
    
    echo "${BUCKET%/}/${PREFIX:1}"
}


function publish() {
    local source=$1
    local destination=$2

    # root level is always "latest"
    S3_URI=$(s3_uri $ASSET_BUCKET $ASSET_STAGE_PATH $destination)

    echo "publishing templates: $S3_URI"
    aws s3 sync \
        --profile asset-publisher \
        --region us-east-1 \
        --acl public-read \
        --delete \
        --metadata commit=$(git rev-parse HEAD) \
        $source \
        $S3_URI
    
    if [[ $USE_RELEASE_TAG && ! -z "$TRAVIS_TAG" ]]; then
        # create explicit pinned versions "latest" and TRAVIS_TAG
        for version in latest $TRAVIS_TAG; do
            S3_URI=$(s3_uri $ASSET_BUCKET $ASSET_STAGE_PATH $version $destination)

            case $destination in
                templates)
                    local parameter=TemplateRootUrl
                    ;;
                artifacts)
                    local parameter=ArtiractRootUrl
                    ;;
                *)
                    echo "unknown destination $destination"
                    exit 1
                    ;;
            esac

            # pin version
            for file in `grep -irl $parameter $source`; do
                local replace="s#/$destination#/$version/$destination#g"
                sed -i '' -e $replace $file
            done

            echo "publishing templates: $S3_URI"
            aws s3 sync \
                --profile asset-publisher \
                --region us-east-1 \
                --acl public-read \
                --delete \
                --metadata commit=$(git rev-parse HEAD) \
                $source \
                $S3_URI
        done
    fi

}


function artifacts() {

    publish ./dist/artifacts artifacts

}


function templates() {

    publish ./dist/templates templates

}


function site() {
    echo "publishing site"
    aws s3 sync \
        --region us-east-1 \
        --acl public-read \
        --delete \
        --metadata commit=$(git rev-parse HEAD) \
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
