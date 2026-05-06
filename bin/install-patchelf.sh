#!/bin/bash -e
APT_OPTS="-o Acquire::Retries=5 -o Acquire::http::Timeout=30 -qq"
for i in 1 2 3 4 5; do
    apt-get $APT_OPTS update && apt-get $APT_OPTS install -y patchelf && break
    echo "apt retry $i/5"
    sleep 10
done
which patchelf || { echo "patchelf install failed after retries"; exit 1; }
