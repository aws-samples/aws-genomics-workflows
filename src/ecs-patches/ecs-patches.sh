#!/bin/bash

echo "=== (re)starting ecs ==="
stop ecs
start ecs
sleep 10
docker images
docker ps
docker logs ecs-agent

echo "=== pulling custom images ==="
docker pull elerch/amazon-ecs-agent
docker pull quay.io/broadinstitute/cromwell-aws-proxy
docker images

echo "=== tagging custom images ==="
docker image tag "amazon/amazon-ecs-agent:latest" "amazon/amazon-ecs-agent:upstream"
docker image tag "elerch/amazon-ecs-agent:latest" "amazon/amazon-ecs-agent:latest"
docker image tag "quay.io/broadinstitute/cromwell-aws-proxy:latest" "ecs-agent-proxy:latest"
docker images

echo "=== removing previous ecs-agent state ==="
stop ecs
rm /var/lib/ecs/data/ecs*.json
start ecs

echo "=== restarting ecs-agent ==="
docker images
docker ps
docker kill ecs-agent
sleep 10
docker images
docker ps

echo "=== logs for ecs-agent ==="
docker logs ecs-agent