#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
mkdir -p /snap/onlyoffice/current
ln -sfn ${DIR}/../build/snap/documentserver /snap/onlyoffice/current/documentserver
ln -sfn ${DIR}/../build/snap/node           /snap/onlyoffice/current/node

FC=${DIR}/../build/snap/documentserver/var-www/onlyoffice/documentserver/server/FileConverter/bin

WORK=$(mktemp -d)
trap "rm -rf $WORK" EXIT
cp ${DIR}/../samples/blank.docx ${WORK}/in.docx
${FC}/x2t ${WORK}/in.docx ${WORK}/out.docx
[ -s ${WORK}/out.docx ] || { echo "x2t produced empty output"; exit 1; }

${FC}/docbuilder -h
