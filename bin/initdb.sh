#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

if [ -z "$SNAP_COMMON" ]; then
    echo "SNAP_COMMON environment variable must be set"
    exit 1
fi

. "${SNAP_DATA}/config/env"

if [[ "$(whoami)" == "onlyoffice" ]]; then
    ${DIR}/postgresql/bin/initdb.sh "$@"
else
    sudo -E -H -u onlyoffice ${DIR}/postgresql/bin/initdb.sh "$@"
fi
