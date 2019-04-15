#!/bin/bash

docker build -t bcftools .
docker build -t bcftools:aws -f aws.dockerfile .