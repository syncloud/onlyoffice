#!/bin/bash -ex

DIR=$( cd "$( dirname "$0" )" && pwd )
cd ${DIR}

BUILD_DIR=${DIR}/../build/snap/documentserver
DST=${BUILD_DIR}/var-www/onlyoffice/documentserver
WORK=${DIR}/../build/upstream
mkdir -p ${DST}/server ${WORK}

apt-get update -qq
apt-get install -y -qq wget xz-utils ca-certificates

IMAGE_VERSION=$1
META_TAG=$(echo "${IMAGE_VERSION}" | awk -F. '{printf "v%s.%s.%s", $1, $2, $3}')
SUBMODULE_API="https://api.github.com/repos/ONLYOFFICE/DocumentServer/contents/server?ref=${META_TAG}"
echo "resolving server submodule pin: image=${IMAGE_VERSION} meta-tag=${META_TAG}"
META_JSON=$(wget -q -O - "${SUBMODULE_API}")
SOURCE_REF=$(echo "${META_JSON}" | node -e 'let s=""; process.stdin.on("data",c=>s+=c); process.stdin.on("end",()=>process.stdout.write(JSON.parse(s).sha))')
[ -n "${SOURCE_REF}" ] || { echo "could not resolve server submodule sha for ${META_TAG}"; echo "${META_JSON}"; exit 1; }
echo "server source ref: ${SOURCE_REF}"

URL=https://github.com/ONLYOFFICE/server/archive/${SOURCE_REF}.tar.gz

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
