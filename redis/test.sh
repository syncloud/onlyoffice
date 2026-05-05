#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
mkdir -p /snap/onlyoffice/current
ln -sfn ${DIR}/../build/snap/redis /snap/onlyoffice/current/redis

BIN=${DIR}/../build/snap/redis/usr/local/bin
${BIN}/redis-server --version
${BIN}/redis-cli --version
${BIN}/redis-benchmark --version
