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
cp -r ${DS}/core-fonts          ${DST}/core-fonts

mkdir -p ${DST}/server/FileConverter
cp -r ${DS}/server/FileConverter/bin ${DST}/server/FileConverter/bin

mkdir -p ${DST}/server/Common
cp -r ${DS}/server/Common/config ${DST}/server/Common/config

cp -r /etc/onlyoffice ${BUILD_DIR}/etc-onlyoffice

API=${DST}/web-apps/apps/api/documents/api.js
cp ${API}.tpl ${API}
sed -i 's/{{HASH_POSTFIX}}/syncloud/g' ${API}

WEB_APPS=${DST}/web-apps/apps
for dep in Window:Window DataViewItem:DataView BaseView:BaseView; do
    cls=${dep%%:*}
    mod=${dep##*:}
    grep -rlZE '^define\(\[\], *function' --include=*.js ${WEB_APPS} \
        | xargs -0 -r grep -lZE "= *Common\.UI\.${cls}\.extend" \
        | xargs -0 -r sed -i -E "s|^define\(\[\], *function|define(['common/main/lib/component/${mod}'], function|"
done
UNDECLARED=$(grep -rlE '^define\(\[\], *function' --include=*.js ${WEB_APPS} | xargs -r grep -lE '= *Common\.UI\.(BaseView|Window|DataViewItem)\.extend' || true)
[ -z "${UNDECLARED}" ] || { echo "web-apps modules still missing base dependency: ${UNDECLARED}"; exit 1; }

UPSTREAM_VERSION=$(sed -nE "/DocEditor\\.version = function/{n;s/.*return '(([0-9]+\\.){2}[0-9]+)'.*/\\1/p;}" ${API}.tpl | head -1)
[ -n "${UPSTREAM_VERSION}" ] || { echo "could not extract version from api.js.tpl"; exit 1; }
COMMONDEFINES=${DST}/server/Common/sources/commondefines.js
[ -f "${COMMONDEFINES}" ] || { echo "${COMMONDEFINES} missing — upstream step must run first"; exit 1; }
echo "patching commondefines.js buildVersion -> ${UPSTREAM_VERSION}"
sed -i "s/^const buildVersion = '[^']*';/const buildVersion = '${UPSTREAM_VERSION}';/" ${COMMONDEFINES}
grep "^const buildVersion" ${COMMONDEFINES}

mkdir -p ${DST}/Data/custom-fonts ${DST}/sdkjs/common/Images ${DST}/fonts
LD_LIBRARY_PATH=${DS}/server/FileConverter/bin \
${DS}/server/tools/allfontsgen \
    --input=${DST}/core-fonts \
    --allfonts-web=${DST}/sdkjs/common/AllFonts.js \
    --allfonts=${DST}/server/FileConverter/bin/AllFonts.js \
    --images=${DST}/sdkjs/common/Images \
    --selection=${DST}/server/FileConverter/bin/font_selection.bin \
    --output-web=${DST}/fonts \
    --use-system=false \
    --use-system-user-fonts=false

# AllFonts.js now embeds absolute paths from --input. At snap runtime
# the documentserver tree lives under /snap/onlyoffice/current/, not
# under /drone/src/build/snap/. Rewrite the paths to the snap location.
SNAP_DST=/snap/onlyoffice/current/documentserver/var-www/onlyoffice/documentserver
sed -i "s,${DST},${SNAP_DST},g" \
    ${DST}/sdkjs/common/AllFonts.js \
    ${DST}/server/FileConverter/bin/AllFonts.js

${DIR}/../bin/install-patchelf.sh
PT_INTERP=/snap/onlyoffice/current/node/lib/oo-arch/oo-ld
FC=${DST}/server/FileConverter/bin

patchelf --set-interpreter "$PT_INTERP" "$FC/x2t"
patchelf --set-interpreter "$PT_INTERP" "$FC/docbuilder"

ln -sfn /snap/onlyoffice/current/node/usr/lib/oo-arch ${FC}/system

chmod -R u+rwX,go+rX ${BUILD_DIR}

du -sh ${BUILD_DIR}
