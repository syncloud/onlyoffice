#!/bin/bash -ex

DIR=$( cd "$( dirname "$0" )" && pwd )
cd ${DIR}

BUILD_DIR=${DIR}/../build/snap/documentserver
DST=${BUILD_DIR}/var-www/onlyoffice/documentserver
WORK=${DIR}/../build/upstream
mkdir -p ${DST}/server ${WORK}

apt-get update -qq
apt-get install -y -qq wget xz-utils

BRANCH=$1
URL=https://github.com/ONLYOFFICE/server/archive/refs/heads/${BRANCH}.tar.gz

cd ${WORK}
wget --tries=3 "${URL}" -O server.tar.gz
ls -la server.tar.gz
mkdir -p server-src
tar -xzf server.tar.gz -C server-src --strip-components=1

for COMPONENT in DocService FileConverter Common SpellChecker Metrics; do
    mkdir -p ${DST}/server/${COMPONENT}
    cp -r ${WORK}/server-src/${COMPONENT}/* ${DST}/server/${COMPONENT}/
done

cp -r ${WORK}/server-src/schema ${DST}/server/schema

for COMPONENT in DocService FileConverter Common; do
    echo "==> npm install for server/${COMPONENT}"
    cd ${DST}/server/${COMPONENT}
    npm ci --omit=dev --no-audit --no-fund
done

du -sh ${BUILD_DIR}
