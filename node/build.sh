#!/bin/sh -ex

DIR=$( cd "$( dirname "$0" )" && pwd )
cd ${DIR}

BUILD_DIR=${DIR}/../build/snap/node
mkdir -p ${BUILD_DIR}

cp -r /usr ${BUILD_DIR}
cp -r /lib ${BUILD_DIR}

mkdir -p ${BUILD_DIR}/bin
cp ${DIR}/bin/* ${BUILD_DIR}/bin

mv ${BUILD_DIR}/usr/lib/*-linux-gnu*       ${BUILD_DIR}/usr/lib/oo-arch
mv ${BUILD_DIR}/usr/lib/oo-arch/ld-linux-* ${BUILD_DIR}/usr/lib/oo-arch/oo-ld

${DIR}/../bin/install-patchelf.sh
PT_INTERP=/snap/onlyoffice/current/node/lib/oo-arch/oo-ld
RPATH=/snap/onlyoffice/current/node/lib/oo-arch:/snap/onlyoffice/current/node/usr/lib/oo-arch
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" ${BUILD_DIR}/usr/local/bin/node

du -sh ${BUILD_DIR}
