#!/bin/bash

echo $USER_K8S_PASSWORD | sudo -S kubeadm init --config /k8s/kubeadm-config.yaml

### Allow kubectl to be run as a non-root user ###
mkdir -p $HOME/.kube
echo $USER_K8S_PASSWORD | sudo -S cp /etc/kubernetes/admin.conf $HOME/.kube/config
echo $USER_K8S_PASSWORD | sudo -S chown "$(id -u):$(id -g)" $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
echo 'export KUBECONFIG=$HOME/.kube/config' >> $HOME/.bashrc
###

# Scheduling pods on control plane nodes
#kubectl taint nodes --all node-role.kubernetes.io/master-
