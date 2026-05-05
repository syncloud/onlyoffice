#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

mkdir -p ${SNAP_DATA}/rabbitmq/{mnesia,log}

export HOME=${SNAP_DATA}/rabbitmq
export RABBITMQ_HOME=${SNAP}/rabbitmq/usr/lib/rabbitmq
export RABBITMQ_MNESIA_BASE=${SNAP_DATA}/rabbitmq/mnesia
export RABBITMQ_LOG_BASE=${SNAP_DATA}/rabbitmq/log
export RABBITMQ_CONFIG_FILE=${SNAP_DATA}/config/rabbitmq
export RABBITMQ_NODENAME=onlyoffice@localhost
export RABBITMQ_DIST_PORT=$(cat ${SNAP_DATA}/secret/rabbit-dist-port)
export RABBITMQ_LOGS=-
export RABBITMQ_USE_LONGNAME=false
export ERL_EPMD_ADDRESS=127.0.0.1
export ERL_EPMD_PORT=$(cat ${SNAP_DATA}/secret/rabbit-epmd-port)

${DIR}/rabbitmq/usr/lib/erlang/bin/epmd -kill 2>/dev/null || true
${DIR}/rabbitmq/usr/lib/erlang/bin/epmd -daemon || true
sleep 1

exec ${DIR}/rabbitmq/bin-syncloud/rabbitmq.sh
