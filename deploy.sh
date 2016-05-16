#!/bin/bash
set -ue

readonly REV=$(git rev-parse --short HEAD)
readonly IMAGE="gcr.io/goonswarm-1303/bads:${REV}"

echo "Deploying BADS revision ${REV}..."

kubectl rolling-update bads --image "${IMAGE}"
