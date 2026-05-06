#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
mkdir -p /snap/onlyoffice/current
ln -sfn ${DIR}/../build/snap/postgresql /snap/onlyoffice/current/postgresql
${DIR}/../build/snap/postgresql/bin/initdb.sh --version
${DIR}/../build/snap/postgresql/bin/pg_ctl.sh --version
