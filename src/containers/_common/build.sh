#!/bin/bash

IMAGE_NAME=$1

# build the base image
docker build -t $IMAGE_NAME .

# build the image with an AWS specific entrypoint
docker build -t $IMAGE_NAME -f aws.dockerfile .