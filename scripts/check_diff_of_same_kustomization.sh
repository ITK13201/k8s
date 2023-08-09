#!/bin/bash -e

set -e

### TO BE UPDATED ###
FILES=(
  "flannel/kustomization.yaml"
  "sealed-secrets/kustomization.yaml"
  "sealed-secrets/values.yaml"
  "namespaces/kustomization.yaml"
)
###

CURRENT_DIR="$( cd "$( dirname "$0" )" && pwd )"
PROJECT_ROOT_PATH="${CURRENT_DIR}/.."
BASE_PATH="${PROJECT_ROOT_PATH}/k8s/overlays"
BASE_DEV_PATH="${BASE_PATH}/dev"
BASE_PROD_PATH="${BASE_PATH}/prod"

exit_code=0
for file in ${FILES[*]}; do
  diff "${BASE_DEV_PATH}/${file}" "${BASE_PROD_PATH}/${file}"
  return_code=$?
  if [ ${return_code} = 1 ]; then
    echo "[ERROR] The difference exists: ${file}" 1>&2
    exit_code=1
  fi
done

if [ ${exit_code} = 0 ]; then
  echo "[INFO] Completed."
fi
exit ${exit_code}
