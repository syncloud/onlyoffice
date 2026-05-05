#!/bin/bash -ex
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${DIR}"

OUT="${DIR}/../build/snap"
mkdir -p "${OUT}/meta/hooks" "${OUT}/bin"

rm -rf "${DIR}/web/assets"
mkdir -p "${DIR}/web/assets"
cp -r "${DIR}/../web/dist/." "${DIR}/web/assets/"

CGO_ENABLED=0 go build -buildvcs=false -o "${OUT}/meta/hooks/install"      ./cmd/install
CGO_ENABLED=0 go build -buildvcs=false -o "${OUT}/meta/hooks/configure"    ./cmd/configure
CGO_ENABLED=0 go build -buildvcs=false -o "${OUT}/meta/hooks/pre-refresh"  ./cmd/pre-refresh
CGO_ENABLED=0 go build -buildvcs=false -o "${OUT}/meta/hooks/post-refresh" ./cmd/post-refresh
CGO_ENABLED=0 go build -buildvcs=false -o "${OUT}/bin/cli"                 ./cmd/cli
CGO_ENABLED=0 go build -buildvcs=false -o "${OUT}/bin/web"                 ./cmd/web
