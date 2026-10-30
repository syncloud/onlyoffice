#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

${DIR}/ci/apt.sh sshpass openssh-client unzip
IP=$(getent hosts ${PLAYWRIGHT_APP_DOMAIN} | awk '{print $1}')
echo "$IP ${PLAYWRIGHT_FULL_DOMAIN} ${PLAYWRIGHT_AUTH_DOMAIN}" >> /etc/hosts
cd ${DIR}/web/e2e
npm ci --no-audit --no-fund
npx playwright test --project=desktop
npx playwright test --project=mobile
