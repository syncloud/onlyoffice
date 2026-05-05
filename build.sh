#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "$DIR"

VERSION=${1:-$(date +%s)}
echo $VERSION > version

drone jsonnet --stdout --stream > .drone.yml
drone exec --pipeline amd64 --trusted \
  --include version \
  --include documentserver \
  --include postgresql \
  --include redis \
  --include rabbitmq \
  --include nginx \
  --include cli \
  --include package \
  .drone.yml
