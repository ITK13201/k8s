#!/bin/bash -eu

set -eu

CURRENT_DIR="$( cd "$( dirname "$0" )" && pwd )"
PROJECT_ROOT_PATH="${CURRENT_DIR}/.."

# import SAME_CONTENT_DEPLOYMENT_FILENAMES
source "${PROJECT_ROOT_PATH}"/scripts/vars/same_content_deployment_filenames.sh

BASE_PATH="${PROJECT_ROOT_PATH}/k8s/overlays"
BASE_DEV_PATH="${BASE_PATH}/dev"
BASE_PROD_PATH="${BASE_PATH}/prod"

exit_code=0
for filename in ${SAME_CONTENT_DEPLOYMENT_FILENAMES[*]}; do
  diff "${BASE_DEV_PATH}/${filename}" "${BASE_PROD_PATH}/${filename}"
  return_code=$?
  if [ ${return_code} = 1 ]; then
    echo "[ERROR] The difference exists: ${filename}" 1>&2
    exit_code=1
  fi
done

if [ ${exit_code} = 0 ]; then
  echo "[INFO] Completed."
fi
exit ${exit_code}
