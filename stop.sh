#!/usr/bin/env bash

set -e

DOCKER_COMMAND="sudo docker"
if [[ "$OSTYPE" == "darwin"* ]]; then
    DOCKER_COMMAND="docker"
fi

$DOCKER_COMMAND compose down
