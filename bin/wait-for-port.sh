#!/bin/bash
HOST=$1
PORT=$2
LABEL=${3:-${HOST}:${PORT}}
retry=0
retries=120
while ! (exec 3<>/dev/tcp/${HOST}/${PORT}) 2>/dev/null; do
    if [[ $retry -gt $retries ]]; then
        echo "waiting for ${LABEL} failed after $retry attempts"
        exit 1
    fi
    retry=$((retry + 1))
    echo "waiting for ${LABEL} $retry/$retries"
    sleep 1
done
exec 3<&-; exec 3>&-
echo "${LABEL} is reachable"
