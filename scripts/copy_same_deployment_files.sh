#!/bin/bash -eu

set -eu

CURRENT_DIR="$( cd "$( dirname "$0" )" && pwd )"
PROJECT_ROOT_PATH="$( realpath "${CURRENT_DIR}/.." )"

# import SAME_CONTENT_DEPLOYMENT_FILENAMES
source "${PROJECT_ROOT_PATH}"/scripts/vars/same_content_deployment_filenames.sh

usage() {
  echo "Usage: $0 [-m]" 1>&2
  echo "Options: " 1>&2
  echo "-m: Define mode (to-dev / to-prod)" 1>&2
  exit 1
}

while getopts :m:h OPT
do
  case $OPT in
  m)  mode=${OPTARG}
      from_env=""
      to_env=""
      if [ "${mode}" = "to-dev" ]; then
        from_env="prod"
        to_env="dev"
      elif [ "${mode}" = "to-prod" ]; then
        from_env="dev"
        to_env="prod"
      else
        echo "[ERROR] wrong mode defined." 1>&2
        exit 1
      fi
      ;;
  h)  usage
      ;;
  \?) usage
      ;;
  esac
done


BASE_PATH="${PROJECT_ROOT_PATH}/k8s/overlays"

for filename in ${SAME_CONTENT_DEPLOYMENT_FILENAMES[*]}; do
  cp -v "${BASE_PATH}/${from_env}/${filename}" "${BASE_PATH}/${to_env}/${filename}"
done

exit
