#!/bin/bash

SECRET_EXIST=$(
  aws secretsmanager list-secrets \
    --filters "Key=name,Values=cromwell/credentials/dockerhub" | jq '.SecretList | length > 0')

if [[ "$SECRET_EXIST" = true ]]; then
  SECRET_STRING=$(aws secretsmanager get-secret-value --secret-id cromwell/credentials/dockerhub --query SecretString --output text)
  echo 'ECS_ENGINE_AUTH_TYPE=docker' >>/etc/ecs/ecs.config
  echo 'ECS_ENGINE_AUTH_DATA={"https://index.docker.io/v1/":'${SECRET_STRING}'}' >>/etc/ecs/ecs.config
fi
