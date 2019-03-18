# Genomics Workflows on AWS

[![Build Status](https://travis-ci.com/aws-samples/aws-genomics-workflows.svg?branch=master)](https://travis-ci.com/aws-samples/aws-genomics-workflows)

This repository is the source code for [Genomics Workflows on AWS](docs.opendata.aws/genomics-workflows).  It contains markdown documents that are used to build the site as well as source code (CloudFormation templates, scripts, etc) that can be used to deploy AWS infrastructure for running genomics workflows.

## Building the documentation

The documentation is built using mkdocs.

Install dependencies:

```bash
$ conda env create --file enviroment.yaml
```

This will create a `conda` environment called `mkdocs`

Build the docs:

```bash
$ source activate mkdocs
$ mkdocs build
```

## License Summary

This sample code is made available under a modified MIT license. See the LICENSE file.