#!/bin/bash

# upgrade dnf packages
dnf upgrade -y
# install netcat
dnf install -y nmap-ncat.x86_64

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
# Ensure that the module is loaded
lsmod | grep br_netfilter
lsmod | grep overlay
# Ensure kernel parameters are set to 1
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
###

### Install container runtime (containerd) ###
dnf remove -y docker \
  docker-client \
  docker-client-latest \
  docker-common \
  docker-latest \
  docker-latest-logrotate \
  docker-logrotate \
  docker-engine
dnf install -y dnf-utils
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# Edit /etc/containerd/config.toml
sed -i 's/^disabled_plugins \=/\#disabled_plugins \=/g' /etc/containerd/config.toml
result_status=0
grep -q "SystemdCgroup = true" /etc/containerd/config.toml || result_status=$?
if [ ! "$result_status" = "0" ]; then
  printf "\n" >> /etc/containerd/config.toml
  cat <<EOF | tee -a /etc/containerd/config.toml
[plugins]
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
      SystemdCgroup = true

  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.k8s.io/pause:3.2"
EOF
fi
# Setting crictl endpoint
crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock --set image-endpoint=unix:///run/containerd/containerd.sock
systemctl enable --now containerd
systemctl restart containerd
###


### Install kubelet kubeadm kubectl ###
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# Set SELinux to permissive mode (effectively disabling it)
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

result_status=0
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes || result_status=$?
if [ ! "$result_status" = "0" ]; then
  dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes --nogpgcheck
fi

result_status=0
grep -q "cgroup-driver" /var/lib/kubelet/kubeadm-flags.env || result_status=$?
if [ ! "$result_status" = "0" ]; then
  echo 'KUBELET_EXTRA_ARGS=--cgroup-driver=systemd' >> /var/lib/kubelet/kubeadm-flags.env
fi
systemctl daemon-reload

systemctl enable --now kubelet
systemctl restart kubelet
###

# delete unused packages
dnf remove -y "$(package-cleanup --leaves)"
