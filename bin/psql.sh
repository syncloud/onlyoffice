#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )
. "${SNAP_DATA}/config/env"
exec ${DIR}/postgresql/bin/psql.sh -h ${PSQL_DATABASE} -p ${PSQL_PORT} "$@"
