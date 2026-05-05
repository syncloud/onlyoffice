#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
mkdir -p /snap/onlyoffice/current
ln -sfn ${DIR}/../build/snap/rabbitmq /snap/onlyoffice/current/rabbitmq

ERTS=$(echo ${DIR}/../build/snap/rabbitmq/usr/lib/erlang/erts-*/bin)
${ERTS}/epmd -daemon
sleep 1
${ERTS}/epmd -names
${ERTS}/epmd -kill
