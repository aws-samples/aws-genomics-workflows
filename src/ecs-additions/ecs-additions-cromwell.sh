#!/bin/bash

# Copyright 2018 Amazon.com, Inc. or its affiliates.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#
#  1. Redistributions of source code must retain the above copyright notice,
#  this list of conditions and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright
#  notice, this list of conditions and the following disclaimer in the
#  documentation and/or other materials provided with the distribution.
#
#  3. Neither the name of the copyright holder nor the names of its
#  contributors may be used to endorse or promote products derived from
#  this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
#  BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
#  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
#  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
#  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
#  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
#  IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.

function error() {
    # exit with an error message
    echo "[ERROR] ($2) $1" >&2
    exit "${2:-1}"
}

function missing_image_error() {
    error "Required container image is missing: $1" 301
}

function incorrect_image_error() {
    error "Incorrect container image: $1 vs $2" 302
}

function missing_container_error() {
    error "Container is missing or could not start: $1" 303
}

function get_image_id() {
    # get the image id for a [repository[:tag]] spec
    docker images --quiet "$1"
}

function get_container_id() {
    # retrieve a container id that is based on the specified image
    local -i max_attempts=${2:-10}
    local -i attempts=0
    local id=""
    while true; do
        local id=$(docker ps --quiet --filter "ancestor=$1")
        if [[ ! -z "$id" ]]; then
            break
        fi

        sleep 1
        (( attempts++ ))

        if [[ $attempts -gt $max_attempts ]]; then
            break
        fi
    done

    echo $id
}

function is_missing_image() {
    local image=$(get_image_id "$1")
    if [[ -z "$image" ]]; then
        missing_image_error $1
    fi
    
    echo "Image found: $1"
}

function is_same_image() {
    local left=$(get_image_id "$1")
    local right=$(get_image_id "$2")

    if [ ! "$left" == "$right" ]; then
        incorrect_image_error $left $right
    fi

    echo "Images match: $1 ($left) vs $2 ($right)"
}

PATCHED_AGENT_IMAGE="elerch/amazon-ecs-agent:latest"
PROXY_IMAGE="quay.io/broadinstitute/cromwell-aws-proxy:latest"

# check the current state of ecs-agent
echo "=== (re)starting ecs ==="
stop ecs
start ecs
sleep 10
docker images
docker ps

# get cromwell specific container images
echo "=== pulling custom images ==="
docker pull $PATCHED_AGENT_IMAGE
docker pull $PROXY_IMAGE
docker images

# check here that the images were successfully downloaded
is_missing_image "$PATCHED_AGENT_IMAGE"
is_missing_image "$PROXY_IMAGE"

echo "=== tagging custom images ==="
docker image tag "amazon/amazon-ecs-agent:latest" "amazon/amazon-ecs-agent:upstream"
docker image tag "$PATCHED_AGENT_IMAGE" "amazon/amazon-ecs-agent:latest"
docker image tag "$PROXY_IMAGE" "ecs-agent-proxy:latest"

echo "=== removing previous ecs-agent state ==="
stop ecs
rm /var/lib/ecs/data/ecs*.json
start ecs

echo "=== restarting ecs-agent ==="
docker kill ecs-agent
sleep 10

echo "=== verifying installation ==="
# check that images are tagged correctly
is_same_image "$PATCHED_AGENT_IMAGE" "amazon/amazon-ecs-agent:latest"
is_same_image "$PROXY_IMAGE" "ecs-agent-proxy:latest"

# check that the ecs-agent container is using the correct image
ecs_agent_container=$(get_container_id "$PATCHED_AGENT_IMAGE")
if [[ -z "$ecs_agent_container" ]]; then
    missing_container_error "ecs-agent"
fi

echo "ECS-Agent container found: $ecs_agent_container"

# if we make it here, things have worked
exit 0