#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )
PGBIN=$(echo ${DIR}/usr/lib/postgresql/*/bin)
exec ${PGBIN}/initdb "$@"
