#!/bin/sh -ex

DIR=$( cd "$( dirname "$0" )" && pwd )
cd ${DIR}

BUILD_DIR=${DIR}/../build/snap/documentserver
mkdir -p ${BUILD_DIR}/var-www/onlyoffice/documentserver

DS=/var/www/onlyoffice/documentserver
DST=${BUILD_DIR}/var-www/onlyoffice/documentserver

cp -r ${DS}/sdkjs               ${DST}/sdkjs
cp -r ${DS}/sdkjs-plugins       ${DST}/sdkjs-plugins
cp -r ${DS}/web-apps            ${DST}/web-apps
cp -r ${DS}/document-templates  ${DST}/document-templates
cp -r ${DS}/dictionaries        ${DST}/dictionaries
cp -r ${DS}/fonts               ${DST}/fonts
cp -r ${DS}/document-formats    ${DST}/document-formats
cp -r ${DS}/npm                 ${DST}/npm

cp -r ${DS}/server ${DST}/server

cp -r /etc/onlyoffice ${BUILD_DIR}/etc-onlyoffice

API=${DST}/web-apps/apps/api/documents/api.js
cp ${API}.tpl ${API}
sed -i 's/{{HASH_POSTFIX}}/syncloud/g' ${API}

UPSTREAM_VERSION=$(sed -nE "s/.*\\* Version: (([0-9]+\\.){2}[0-9]+).*/\\1/p" ${API}.tpl | head -1)
[ -n "${UPSTREAM_VERSION}" ] || { echo "could not extract version from api.js.tpl"; exit 1; }
COMMONDEFINES=${DST}/server/Common/sources/commondefines.js
[ -f "${COMMONDEFINES}" ] || { echo "${COMMONDEFINES} missing"; exit 1; }
echo "patching commondefines.js buildVersion -> ${UPSTREAM_VERSION}"
sed -i "s/^const buildVersion = '[^']*';/const buildVersion = '${UPSTREAM_VERSION}';/" ${COMMONDEFINES}
grep "^const buildVersion" ${COMMONDEFINES}

mkdir -p ${DST}/Data/custom-fonts ${DST}/sdkjs/common/Images ${DST}/fonts
LD_LIBRARY_PATH=${DS}/server/FileConverter/bin \
${DS}/server/tools/allfontsgen \
    --input=${DS}/core-fonts \
    --allfonts-web=${DST}/sdkjs/common/AllFonts.js \
    --allfonts=${DST}/server/FileConverter/bin/AllFonts.js \
    --images=${DST}/sdkjs/common/Images \
    --selection=${DST}/server/FileConverter/bin/font_selection.bin \
    --output-web=${DST}/fonts \
    --use-system=true \
    --use-system-user-fonts=false

${DIR}/../bin/install-patchelf.sh
PT_INTERP=/snap/onlyoffice/current/node/lib/oo-arch/oo-ld
FC=${DST}/server/FileConverter/bin

patchelf --set-interpreter "$PT_INTERP" "$FC/x2t"
patchelf --set-interpreter "$PT_INTERP" "$FC/docbuilder"

ln -sfn /snap/onlyoffice/current/node/usr/lib/oo-arch ${FC}/system

chmod -R u+rwX,go+rX ${BUILD_DIR}

du -sh ${BUILD_DIR}
