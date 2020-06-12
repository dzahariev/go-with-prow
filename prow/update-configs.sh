#!/bin/bash

set -x 

kubectl create configmap config \
  --from-file=config.yaml=config.yaml --dry-run=client -o yaml | kubectl replace configmap config -f -

kubectl scale deploy hook --replicas=0
kubectl scale deploy plank --replicas=0
kubectl scale deploy crier --replicas=0
sleep 1
kubectl scale deploy hook --replicas=1
kubectl scale deploy plank --replicas=1
kubectl scale deploy crier --replicas=1