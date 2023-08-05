# Kubernetes (Local)

## Vagrant

### Start VM

```shell
vagrant up --provision
```

### Reload Vagrantfile

```shell
IS_PROVISIONED=1 vagrant reload
```

### Provision

```shell
vagrant provision
```

### rsync

```shell
IS_PROVISIONED=1 vagrant rsync-auto
```

### Run Vbguest

```shell
vagrant vbguest
```
