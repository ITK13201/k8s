#!/bin/bash

set -eu

### TO BE UPDATED ###
FILENAMES=(
  "nextcloud/nextcloud-secret"
  "nextcloud/mariadb-secret"
  "nextcloud/redis-secret"
)
###

usage() {
  echo "Usage: $0 [-m] [-p]" 1>&2
  echo "Options: " 1>&2
  echo "-m: Define mode (dev / prod)" 1>&2
  exit 1
}

while getopts :m:h OPT
do
  case $OPT in
  m)  mode=${OPTARG}
      ;;
  h)  usage
      ;;
  \?) usage
      ;;
  esac
done

CURRENT_DIR="$( cd "$( dirname "$0" )" && pwd )"
PROJECT_ROOT_PATH="${CURRENT_DIR}/.."

CREDENTIAL_BASE_PATH="${PROJECT_ROOT_PATH}/credentials"
DEPLOYMENT_BASE_PATH="${PROJECT_ROOT_PATH}/k8s/overlays"

for filename in "${FILENAMES[@]}"; do
  namespace="$(echo ${filename} | cut -d'/' -f1)"
  secret_name="$(echo ${filename} | cut -d'/' -f2)"
  kubectl create secret generic ${secret_name} \
    --dry-run=client \
    --from-env-file="${CREDENTIAL_BASE_PATH}/${mode}/${filename}.env" \
    -n "${namespace}" \
    -o yaml \
    > "${DEPLOYMENT_BASE_PATH}/${mode}/${filename}-plain.yaml"
done

exit
