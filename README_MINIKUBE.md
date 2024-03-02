# Kubernetes (Minikube)

## Usage

### Start cluster

```
minikube start \
  --cpus=4 \
  --memory=8192
```

### Delete cluster

```shell
minikube delete
```

### Show Minikube profile

```shell
minikube profile list
```

### Create tunnel

```shell
minikube tunnel
```

### Minikube addons

#### List

```shell
minikube addons list
```

#### Addons

```shell
minikube dashboard
```

### Load local images

**Caution!**: Always use tags other than 'latest' for local images.

```shell
minikube image load <IMAGE>:<TAG>
```

## Cautions

### Make dirs to minikube vm

```shell
minikube ssh
mkdir <PATH>
```
