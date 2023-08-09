# Kubernetes

## READMEs per Environment

### Local README

[./README_LOCAL](./README_LOCAL.md)

### Production README

[./README_PRODUCTION](./README_PRODUCTION.md)


## Usage

### Create Secret

```shell
kubectl create secret generic <SECRET_NAME> --dry-run=client --from-env-file=<ENV_FILE_PATH> -n <NAMESPACE> -o yaml > <OUTPUT_FILE_PATH>
```

### Fetch public key from pod

After deploying the `sealed-secrets` pod, execute the following command.

```shell
kubeseal --fetch-cert > cert.pub
```

### Encrypt Secret

```shell
./scripts/encrypt_secrets.sh -m <dev/prod> -p <PUBLIC_KEY_PATH>
```
