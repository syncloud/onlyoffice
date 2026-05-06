#!/bin/sh -ex

DIR=$( cd "$( dirname "$0" )" && pwd )
cd ${DIR}
BUILD_DIR=${DIR}/../build/snap/rabbitmq
mkdir -p $BUILD_DIR

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq rabbitmq-server

cp -r /usr ${BUILD_DIR}
cp -r /lib ${BUILD_DIR}
cp -r /etc/rabbitmq ${BUILD_DIR}/etc-rabbitmq

ERL=${BUILD_DIR}/usr/lib/erlang/bin/erl
sed -i 's|ROOTDIR=/usr/lib/erlang|ROOTDIR=/snap/onlyoffice/current/rabbitmq/usr/lib/erlang|g' "$ERL"

cp -r ${DIR}/bin ${BUILD_DIR}/bin-syncloud

mv ${BUILD_DIR}/usr/lib/*-linux-gnu*       ${BUILD_DIR}/usr/lib/oo-arch
mv ${BUILD_DIR}/usr/lib/oo-arch/ld-linux-* ${BUILD_DIR}/usr/lib/oo-arch/oo-ld

apt-get install -y -qq patchelf
PT_INTERP=/snap/onlyoffice/current/rabbitmq/lib/oo-arch/oo-ld
RPATH=/snap/onlyoffice/current/rabbitmq/lib/oo-arch:/snap/onlyoffice/current/rabbitmq/usr/lib/oo-arch

ERTS=${BUILD_DIR}/usr/lib/erlang/erts-*/bin
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/beam.smp
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/dyn_erl
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/epmd
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/erlc
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/erl_call
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/erl_child_setup
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/erlexec
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/escript
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/heart
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/inet_gethost
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/run_erl
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/to_erl
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/typer
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $ERTS/yielding_c_fun

OS_MON=${BUILD_DIR}/usr/lib/erlang/lib/os_mon-*/priv/bin
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $OS_MON/memsup
patchelf --set-interpreter "$PT_INTERP" --set-rpath "$RPATH" $OS_MON/cpu_sup

patchelf --set-rpath "$RPATH" ${BUILD_DIR}/usr/lib/erlang/lib/*/priv/lib/*.so
patchelf --set-rpath "$RPATH" ${BUILD_DIR}/usr/lib/oo-arch/lib*.so*

du -sh ${BUILD_DIR}
