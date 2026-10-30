#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

DISTRO=$1
APP=$2

cd ${DIR}/test
./deps.sh
py.test -x -s test.py --distro=${DISTRO} --ver=${DRONE_BUILD_NUMBER} --app=${APP}
