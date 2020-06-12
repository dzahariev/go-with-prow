#!/bin/bash

set -x 

kubectl create configmap plugins \
  --from-file=plugins.yaml=plugins.yaml --dry-run=client -o yaml | kubectl replace configmap plugins -f -

sh reload.sh