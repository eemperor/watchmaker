#!/bin/bash
set -eu -o pipefail

[[ $# -lt 3 ]] && {
    echo "Usage $0 <PROJECT_NAME> <S3_KEYFIX> <WAM_VERSION>" >&2
    echo "  Example: $0 xyz-project s3-bucket/path 0.23.1" >&2
    exit 1
}

PROJECT_NAME=$1
S3_KEYFIX=$2
WAM_VERSION=$3

CB_ENV_OVERRIDE='[{"name":"TF_VAR_s3_scan_bucket","value":"'"$S3_KEYFIX"'","type":"PLAINTEXT"},{"name":"TF_VAR_wam_version","value":"'"$WAM_VERSION"'","type":"PLAINTEXT"},{"name":"TF_VAR_standalone_builds","value":"[\"centos7\",\"rhel7\"]","type":"PLAINTEXT"},{"name":"TF_VAR_source_builds","value":"[]","type":"PLAINTEXT"}]'

WAIT_INTERVAL=30 #in seconds

if [ -z $(aws codebuild list-projects  --output text --query "projects[? @ == '${PROJECT_NAME}']") ]; then
  echo "Codebuild project not found!"
  exit 1
else
  echo "Codebuild project found!  Starting build job..."
  BUILD_ID=$(aws codebuild start-build --project-name ${PROJECT_NAME} --environment-variables-override ${CB_ENV_OVERRIDE} --output text --query 'build.id')
fi

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
