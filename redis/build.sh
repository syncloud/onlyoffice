#!/bin/sh -ex

DIR=$( cd "$( dirname "$0" )" && pwd )
cd ${DIR}
BUILD_DIR=${DIR}/../build/snap/redis
mkdir -p $BUILD_DIR
cp -r /usr ${BUILD_DIR}
cp -r /lib ${BUILD_DIR}
cp -r ${DIR}/bin ${BUILD_DIR}/bin

mv ${BUILD_DIR}/usr/lib/*-linux-gnu*       ${BUILD_DIR}/usr/lib/oo-arch
mv ${BUILD_DIR}/usr/lib/oo-arch/ld-linux-* ${BUILD_DIR}/usr/lib/oo-arch/oo-ld

${DIR}/../bin/install-patchelf.sh
PT_INTERP=/snap/onlyoffice/current/redis/lib/oo-arch/oo-ld
RPATH=/snap/onlyoffice/current/redis/lib/oo-arch:/snap/onlyoffice/current/redis/usr/lib/oo-arch
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" ${BUILD_DIR}/usr/local/bin/redis-server
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" ${BUILD_DIR}/usr/local/bin/redis-cli
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" ${BUILD_DIR}/usr/local/bin/redis-benchmark
