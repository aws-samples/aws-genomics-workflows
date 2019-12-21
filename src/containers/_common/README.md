# Common assets for tooling containers

These are assets that are used to build all tooling containers.

* `build.sh`: a generic build script that first builds a base image for a container, then builds an AWS specific image
* `entrypoint.aws.sh`: a generic entrypoint script that wraps a call to a binary tool in the container with handlers data staging from/to S3
