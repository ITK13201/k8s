#!/bin/bash -eu

set -eu

CURRENT_DIR="$( cd "$( dirname "$0" )" && pwd )"
PROJECT_ROOT_PATH=$(realpath "${CURRENT_DIR}/..")

CREDENTIAL_BASE_PATH="${PROJECT_ROOT_PATH}/credentials"
DEPLOYMENT_BASE_PATH="${PROJECT_ROOT_PATH}/secrets"

readarray -t namespaces < <(find "${CREDENTIAL_BASE_PATH}" -maxdepth 1 -mindepth 1 -type d -printf "%f\n")
for namespace in "${namespaces[@]}"; do
  readarray -t filenames < <(find "${CREDENTIAL_BASE_PATH}/${namespace}" -maxdepth 1 -mindepth 1 -type f -printf "%f\n")
  for filename in "${filenames[@]}"; do
    secret_name=$(basename "${filename}" .env)
    kubectl create secret generic "${secret_name}" \
    --dry-run=client \
    --from-env-file="${CREDENTIAL_BASE_PATH}/${namespace}/${filename}" \
    -n "${namespace}" \
    -o yaml \
    > "${DEPLOYMENT_BASE_PATH}/${namespace}/${secret_name}.yaml"
  done
done

exit
