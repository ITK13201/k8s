#!/bin/bash

set -e

GENERATED_DEPLOYMENTS_DIR="/srv/tmp/k8s/generated"
DEPLOYMENTS=(
  "namespaces"
  "pv"
  "nextcloud"
)

## Deploying deployments
for deployment in ${DEPLOYMENTS[*]}; do
  kubectl apply -f ${GENERATED_DEPLOYMENTS_DIR}/"${deployment}".yaml
done

exit
