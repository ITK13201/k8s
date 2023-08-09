#!/bin/bash

set -eu

### TO BE UPDATED ###
FILES=(
  "nextcloud/nextcloud-secret"
  "nextcloud/mariadb-secret"
  "nextcloud/redis-secret"
)
###

usage() {
  echo "Usage: $0 [-m] [-p]" 1>&2
  echo "Options: " 1>&2
  echo "-m: Define mode (dev / prod)" 1>&2
  echo "-p: Define public key path (e.g., cert.pub)" 1>&2
  exit 1
}

while getopts :m:p:h OPT
do
  case $OPT in
  m)  mode=${OPTARG}
      ;;
  p)  public_key_path=${OPTARG}
      ;;
  h)  usage
      ;;
  \?) usage
      ;;
  esac
done

CURRENT_DIR="$( cd "$( dirname "$0" )" && pwd )"
PROJECT_ROOT_PATH="${CURRENT_DIR}/.."
BASE_PATH="${PROJECT_ROOT_PATH}/k8s/overlays"

for file in "${FILES[@]}"; do
  kubeseal --format=yaml --cert="${public_key_path}" \
    < "${BASE_PATH}/${mode}/${file}"-plain.yaml \
    > "${BASE_PATH}/${mode}/${file}".yaml
done

exit
