#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )
$DIR/bin/wait-for-configure.sh
. "${SNAP_DATA}/config/env"
rm -f ${SNAP_DATA}/run/web.sock
exec $DIR/bin/web
