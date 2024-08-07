#!/usr/bin/env bash

set -e

DOCKER_COMMAND="sudo docker"
if [[ "$OSTYPE" == "darwin"* ]]; then
    DOCKER_COMMAND="docker"
fi

echo $(pwd)

$DOCKER_COMMAND compose -f compose.yaml build _dev_build
$DOCKER_COMMAND compose -f compose.yaml up -d
$DOCKER_COMMAND compose -f compose.yaml exec dev zsh
