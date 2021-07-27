#!/bin/bash
set -eu -o pipefail

[[ $# -lt 2 ]] && {
    echo "Usage $0 <PROJECT_NAME> <CB_ENV_OVERRIDE>" >&2
    echo "  Example: $0 xyz-project file://xyz.json" >&2
    exit 1
}

PROJECT_NAME=$1
CB_ENV_OVERRIDE=$2
BUILD_ID=$(aws codebuild start-build --project-name ${PROJECT_NAME} --environment-variables-override ${CB_ENV_OVERRIDE} --output text --query 'build.id')
WAIT_INTERVAL=30 #in seconds

echo "Build job started!"

build_status() {
  aws codebuild batch-get-builds --ids ${BUILD_ID} --query 'builds[*].buildStatus' --output text
}

echo "Start checking status for build..."

while [ "$(build_status)" == "IN_PROGRESS" ]; do
  echo "[codebuild_start_wait]: Build is still in progress. Check again in a ${WAIT_INTERVAL} seconds..."
  sleep ${WAIT_INTERVAL}
done

if [ "$(build_status)" == "FAILED" ]; then
  echo "Build has FAILED"
  exit 1
fi

exit 0
