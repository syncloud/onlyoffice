#!/bin/sh -xe

DIR=$( cd "$( dirname "$0" )" && pwd )
cd ${DIR}

BUILD_DIR=${DIR}/../build/snap/postgresql

mkdir -p ${BUILD_DIR}

rm -rf usr/lib/*/perl
rm -rf usr/lib/*/perl-base
rm -rf usr/lib/*/dri
rm -rf usr/lib/*/mfx
rm -rf usr/lib/*/vdpau
rm -rf usr/lib/*/gconv
rm -rf usr/lib/*/lapack
rm -rf usr/lib/gcc
rm -rf usr/lib/git-core

cp -r /usr ${BUILD_DIR}
cp -r /lib ${BUILD_DIR}

mkdir ${BUILD_DIR}/bin
cp $DIR/bin/* ${BUILD_DIR}/bin

mv ${BUILD_DIR}/usr/lib/*-linux-gnu*       ${BUILD_DIR}/usr/lib/oo-arch
mv ${BUILD_DIR}/usr/lib/oo-arch/ld-linux-* ${BUILD_DIR}/usr/lib/oo-arch/oo-ld

${DIR}/../bin/install-patchelf.sh
PT_INTERP=/snap/onlyoffice/current/postgresql/lib/oo-arch/oo-ld
RPATH=/snap/onlyoffice/current/postgresql/lib/oo-arch:/snap/onlyoffice/current/postgresql/usr/lib/oo-arch:/snap/onlyoffice/current/postgresql/usr/lib/postgresql/16/lib
PGBIN=$(echo ${BUILD_DIR}/usr/lib/postgresql/*/bin)
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" ${PGBIN}/*
patchelf --set-rpath "$RPATH" ${BUILD_DIR}/usr/lib/oo-arch/lib*.so*
patchelf --set-rpath "$RPATH" ${BUILD_DIR}/usr/lib/postgresql/16/lib/*.so
