#!/bin/bash

set -e

DEVELOPMENTS_DIR="/srv/k8s/deployments"
GENERATED_DIR="/srv/k8s/generated"

DEPLOYMENTS=(
  "flannel"
  "sealed-secrets"
)

for deployment in ${DEPLOYMENTS[*]}; do
  kubectl kustomize --enable-helm ${DEVELOPMENTS_DIR}/"${deployment}" -o ${GENERATED_DIR}/"${deployment}".yaml
done

exit
