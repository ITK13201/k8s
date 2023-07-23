# Kubernetes (Production)

## Ansible

### Bootstrap

```shell
ansible-playbook -v -i ./ansible/prod_hosts ./ansible/bootstrap.yaml --private-key {{ private_key_path }} --ask-vault-pass
```
