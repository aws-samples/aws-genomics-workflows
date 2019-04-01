#!/bin/bash

set -e

bash _scripts/make-artifacts.sh
mkdocs build


echo "publishing artifacts:"
aws s3 sync \
    --profile asset-publisher \
    --acl public-read \
    --delete \
    ./artifacts \
    s3://aws-genomics-workflows/artifacts


echo "publishing templates:"
aws s3 sync \
    --profile asset-publisher \
    --acl public-read \
    --delete \
    --metadata commit=$(git rev-parse HEAD) \
    ./src/templates \
    s3://aws-genomics-workflows/templates


echo "publishing site"
aws s3 sync \
    --acl public-read \
    --delete \
    ./site \
    s3://docs.opendata.aws/genomics-workflows

