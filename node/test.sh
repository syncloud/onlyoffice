#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
mkdir -p /snap/onlyoffice/current
ln -sfn ${DIR}/../build/snap/node /snap/onlyoffice/current/node

BIN=${DIR}/../build/snap/node/usr/local/bin
export PATH=${BIN}:$PATH

${BIN}/node --version
${BIN}/node -e "console.log(require('crypto').createHash('sha256').update('x').digest('hex'))"
${BIN}/npm --version
