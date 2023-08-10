#!/bin/bash

set -e

GENERATED_DEPLOYMENTS_DIR="/srv/tmp/k8s/generated"


# Scheduling pods on control plane nodes
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Deploying flannel
kubectl apply -f ${GENERATED_DEPLOYMENTS_DIR}/flannel.yaml

# Wait for flannel pod initialization
echo "Wait for flannel pods initialization... (1 minute)"
sleep 1m

# Deploying sealed-secrets
kubectl apply -f ${GENERATED_DEPLOYMENTS_DIR}/sealed-secrets.yaml

# Wait for flannel pod initialization
echo "Wait for sealed-secrets pods initialization... (1 minute)"
sleep 1m

echo "Completed."

exit
