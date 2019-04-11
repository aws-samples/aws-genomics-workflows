#!/bin/bash

docker build -t samtools .
docker build -t samtools:aws -f aws.dockerfile .