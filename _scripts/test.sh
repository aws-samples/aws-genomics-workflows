#!/bin/bash

set -e

# check cfn templates for errors
cfn-lint --version
cfn-lint src/templates/**/*.template.yaml

# make sure that site can build
mkdocs build