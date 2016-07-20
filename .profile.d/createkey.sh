#!/usr/bin/env bash

# For easypeasy
# grap the RSA key and write it to a file so we can use that later to ssh to prod
echo "checking..."
if [ "$EPMETA_RSA_KEY" ]; then
    var="$EPMETA_RSA_KEY"
    dest="epprod.key"
    echo "$var" > "$dest"
    echo "key written to epprod.key in current folder"
else
  echo "env var EPMETA_RSA_KEY not found"
fi
