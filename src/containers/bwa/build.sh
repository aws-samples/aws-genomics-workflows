#!/bin/bash

docker build -t bwa .
docker build -t bwa:aws -f aws.dockerfile .