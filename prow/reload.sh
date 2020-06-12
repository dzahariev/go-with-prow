#!/bin/bash

set -x 

kubectl scale deploy hook --replicas=0
kubectl scale deploy plank --replicas=0
kubectl scale deploy crier --replicas=0
sleep 1
kubectl scale deploy hook --replicas=1
kubectl scale deploy plank --replicas=1
kubectl scale deploy crier --replicas=1