#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )
$DIR/bin/wait-for-configure.sh

$DIR/bin/wait-for-port.sh 127.0.0.1 "$(cat ${SNAP_DATA}/secret/rabbit-port)" rabbitmq

. "${SNAP_DATA}/config/env"

export PATH=${SNAP}/node/usr/local/bin:$PATH

DS_HOME=${SNAP}/documentserver/var-www/onlyoffice/documentserver
cd ${DS_HOME}/server/FileConverter

exec ${SNAP}/node/bin/node.sh sources/convertermaster.js
