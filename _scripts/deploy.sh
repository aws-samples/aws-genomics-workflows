#!/bin/bash

set -e

bash _scripts/make-artifacts.sh
mkdocs build


echo "publishing artifacts:"
aws s3 cp \
    --profile asset-publisher \
    --acl public-read \
    --recursive \
    ./artifacts \
    s3://aws-genomics-workflows/artifacts


echo "publishing templates:"
aws s3 cp \
    --profile asset-publisher \
    --acl public-read \
    --recursive \
    --metadata commit=$(git rev-parse HEAD) \
    ./src/templates \
    s3://aws-genomics-workflows/templates


echo "publishing site"
aws s3 cp \
    --acl public-read \
    --recursive \
    ./site \
    s3://docs.opendata.aws/genomics-workflows

