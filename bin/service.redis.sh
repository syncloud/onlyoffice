#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )
mkdir -p ${SNAP_DATA}/redis ${SNAP_DATA}/run
rm -f ${SNAP_DATA}/run/redis.sock
exec ${DIR}/redis/bin/redis.sh ${SNAP_DATA}/config/redis.conf
