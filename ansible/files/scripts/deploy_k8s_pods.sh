#!/bin/bash

set -e

GENERATED_DEPLOYMENTS_DIR="/srv/k8s/generated"
DEPLOYMENTS=(
)


# Scheduling pods on control plane nodes
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Deploying flannel
kubectl apply -f ${GENERATED_DEPLOYMENTS_DIR}/flannel.yaml

# Wait for flannel pod initialization
echo "Wait for flannel pods initialization... (1 minute)"
sleep 1m

# Deploying deployments
for deployment in ${DEPLOYMENTS[*]}; do
  kubectl apply -f ${GENERATED_DEPLOYMENTS_DIR}/"${deployment}".yaml
done

exit
