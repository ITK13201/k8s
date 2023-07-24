#!/bin/bash

# Scheduling pods on control plane nodes
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Deploying Flannel with kubectl
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
