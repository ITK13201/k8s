# Kubernetes (Local)

## Setup

### 1. Vagrant up with provision

```shell
vagrant up --provision
```

### 2. Update VirtualBox Guest Additions

```shell
vagrant vbguest
```

### 3. Vagrant reload

*When using the `rsync-auto` command, if the `reload` command is not executed, the user will remain at the initialization time.

```shell
IS_PROVISIONED=1 vagrant reload
```

## Vagrant

### Start VM with provision

```shell
vagrant up --provision
```

### Reload

```shell
IS_PROVISIONED=1 vagrant reload
```

### Provision

```shell
vagrant provision
```

### Rsync

```shell
vagrant rsync-auto
```

### Update VirtualBox Guest Additions

```shell
vagrant vbguest
```

## Documentation

### kubernetes Nodeports

|  Service  | Nodeport |
|:---------:|:--------:|
| nextcloud |  31000   |
