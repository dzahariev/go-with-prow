#!/bin/bash

set -x 

kubectl create configmap config \
  --from-file=config.yaml=config.yaml --dry-run=client -o yaml | kubectl replace configmap config -f -

sh reload.sh