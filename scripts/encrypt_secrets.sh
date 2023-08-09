#!/bin/bash -eu

set -eu

CURRENT_DIR="$( cd "$( dirname "$0" )" && pwd )"
PROJECT_ROOT_PATH="${CURRENT_DIR}/.."
BASE_PATH="${PROJECT_ROOT_PATH}/k8s/overlays"

# import SECRET_FILENAMES
source "${PROJECT_ROOT_PATH}"/scripts/vars/secret_filenames.sh

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

for filename in "${SECRET_FILENAMES[@]}"; do
  kubeseal --format=yaml --cert="${public_key_path}" \
    < "${BASE_PATH}/${mode}/${filename}"-plain.yaml \
    > "${BASE_PATH}/${mode}/${filename}".yaml
done

exit
