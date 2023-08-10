# Kubernetes

## READMEs per Environment

### Local README

[./README_LOCAL](./README_LOCAL.md)

### Production README

[./README_PRODUCTION](./README_PRODUCTION.md)


## Usage

### Create Secret

```shell
bash ./scripts/create_secrets.sh -m <dev/prod>
```

### Fetch public key from pod

After deploying the `sealed-secrets` pod, execute the following command.

```shell
kubeseal --fetch-cert > cert.pub
```

### Encrypt Secret

```shell
bash ./scripts/encrypt_secrets.sh -m <dev/prod> -p <PUBLIC_KEY_PATH>
```
