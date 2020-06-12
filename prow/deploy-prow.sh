#!/bin/bash

set -x

kubectl create secret generic hmac-token --from-file=hmac=tokens/hmac.token
kubectl create secret generic oauth-token --from-file=oauth=tokens/oauth.token
#kubectl create secret generic slack-token --from-file=slack=tokens/slack.token
#kubectl create secret generic kubeconfig --from-file=slack=tokens/kubeconfig

#prow
kubectl apply -f https://raw.githubusercontent.com/kubernetes/test-infra/master/config/prow/cluster/starter.yaml

#crier
kubectl apply -f job-config.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes/test-infra/master/config/prow/cluster/crier_rbac.yaml
#kubectl apply -f https://raw.githubusercontent.com/kubernetes/test-infra/master/config/prow/cluster/crier_deployment.yaml
kubectl apply -f crier_deployment.yaml
