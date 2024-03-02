#!/bin/bash

### VERSIONS ###
CALICO_VERSION=3.27.0
###

set -e

sudo kubeadm init --config /usr/local/etc/kubeadm/config.yaml

### Allow kubectl to be run as a non-root user ###
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown "$(id -u):$(id -g)" $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
echo "export KUBECONFIG=$HOME/.kube/config" >> $HOME/.bashrc
###

# Deploying calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/custom-resources.yaml

# Confirm calico
watch kubectl get pods -n calico-system

# Scheduling pods on control plane nodes
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Install calicoctl
curl -L https://github.com/projectcalico/calico/releases/download/v${CALICO_VERSION}/calicoctl-linux-amd64 -o calicoctl
chmod +x ./calicoctl
sudo mv ./calicoctl /usr/local/bin

echo "Completed."

exit