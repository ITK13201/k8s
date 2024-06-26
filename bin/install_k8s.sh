#!/bin/bash

set -e

### Versions ###
CONTAINERD_VERSION=1.7.11
RUNC_VERSION=1.1.10
CNI_PLUGINS_VERSION=1.4.0
CRICTL_VERSION=1.29.0
###

# add /usr/bin/local to PATH env (as sudo)
export PATH="/usr/local/bin:$PATH"

# install netcat
dnf install -y nmap-ncat wget git

# disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

### Enable IPv4 forwarding to make bridged traffic visible from iptables ###
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
# Apply kernel parameters without rebooting
sysctl --system
###

### Install container runtime (containerd) ###
# Download binary
wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
tar -C /usr/local -xzvf containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
rm -f containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

# Make setting files
mkdir /etc/containerd/
containerd config default > /etc/containerd/config.toml
sed -i 's|SystemdCgroup = false|SystemdCgroup = true|' /etc/containerd/config.toml

# Setting systemd
mkdir -p /usr/local/lib/systemd/system
wget -O /usr/local/lib/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

# Installing runc
wget https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc
rm -f runc.amd64

# Installing CNI plugins
wget https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz
mkdir -p /opt/cni/bin
tar -C /opt/cni/bin -xzvf cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz
rm -f cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz

# Install crictl
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz
tar -C /usr/local/bin -xzvf crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz
rm -f crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz
crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock --set image-endpoint=unix:///run/containerd/containerd.sock

systemctl daemon-reload
systemctl enable --now containerd
systemctl restart containerd
###


### Install kubelet kubeadm kubectl ###
# Set SELinux in permissive mode (effectively disabling it)
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# This overwrites any existing configuration in /etc/yum.repos.d/kubernetes.repo
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet
###

### Install helm ###
wget -O get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm -f ./get_helm.sh
###

# delete unused packages
dnf remove -y "$(package-cleanup --leaves)"

exit
