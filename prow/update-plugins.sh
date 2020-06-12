#!/bin/bash

set -x 

kubectl create configmap plugins \
  --from-file=plugins.yaml=plugins.yaml --dry-run=client -o yaml | kubectl replace configmap plugins -f -

kubectl scale deploy hook --replicas=0
kubectl scale deploy plank --replicas=0
kubectl scale deploy crier --replicas=0
sleep 1
kubectl scale deploy hook --replicas=1
kubectl scale deploy plank --replicas=1
kubectl scale deploy crier --replicas=1