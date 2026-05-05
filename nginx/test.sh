#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
mkdir -p /snap/onlyoffice/current
ln -sfn ${DIR}/../build/snap/nginx /snap/onlyoffice/current/nginx
${DIR}/../build/snap/nginx/bin/nginx.sh -v
