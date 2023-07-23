# Local

## Vagrant

### Start VM

```shell
vagrant up --provision
```

### Reload Vagrantfile

```shell
vagrant reload
```

## Provision

```shell
vagrant provision
```

## Setup before `kubeadm init`

add `node-ip` to `KUBELET_DNS_ARGS` in `/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf`

e.g.)
```shell
Environment="KUBELET_DNS_ARGS=--cluster-dns=10.244.0.10 --cluster-domain=cluster.local --node-ip=172.16.20.11"
```

after that

```shell
systemctl daemon-reload
systemctl restart kubelet
```
