#!/bin/bash

set -e

mode=$1
if [ "${mode}" != "dev" ] && [ "${mode}" != "prod" ]; then
  echo "[ERROR] Mode (dev or prod) is not specified." 1>&2
  exit 1
fi

DEVELOPMENTS_DIR="/srv/k8s/overlays/${mode}"
GENERATED_DIR="/srv/k8s/generated"

DEPLOYMENTS=(
  "namespaces"
  "flannel"
  "sealed-secrets"
  "nextcloud"
  "pv"
)

for deployment in ${DEPLOYMENTS[*]}; do
  kubectl kustomize --enable-helm "${DEVELOPMENTS_DIR}"/"${deployment}" -o ${GENERATED_DIR}/"${deployment}".yaml
done

exit
