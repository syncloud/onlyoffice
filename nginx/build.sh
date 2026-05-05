#!/bin/sh -ex

DIR=$( cd "$( dirname "$0" )" && pwd )
cd ${DIR}

BUILD_DIR=${DIR}/../build/snap/nginx
mkdir -p ${BUILD_DIR}
cp -r /etc ${BUILD_DIR}
cp -r /usr ${BUILD_DIR}
cp -r /lib ${BUILD_DIR}
mkdir -p ${BUILD_DIR}/bin
cp -r ${DIR}/bin/* ${BUILD_DIR}/bin

mv ${BUILD_DIR}/lib/ld-musl-*.so.* ${BUILD_DIR}/lib/oo-ld

apk add --no-cache patchelf
patchelf --set-interpreter /snap/onlyoffice/current/nginx/lib/oo-ld \
         --set-rpath /snap/onlyoffice/current/nginx/lib:/snap/onlyoffice/current/nginx/usr/lib \
         ${BUILD_DIR}/usr/sbin/nginx
