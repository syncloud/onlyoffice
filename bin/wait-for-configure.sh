#!/bin/bash
retry=0
retries=100
APP=onlyoffice
NEXT=/snap/$APP/current/version
CURRENT=/var/snap/$APP/current/version
while ! diff $NEXT $CURRENT > /dev/null 2>&1; do
    if [[ $retry -gt $retries ]]; then
        echo "waiting for snap configure failed after $retry attempts"
        exit 1
    fi
    retry=$((retry + 1))
    echo "waiting for snap configure $retry/$retries"
    sleep 2
done
echo "snap is configured"
