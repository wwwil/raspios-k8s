#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

IMAGE_LINK=https://downloads.raspberrypi.org/raspios_arm64/images/raspios_arm64-2020-05-28/2020-05-27-raspios-buster-arm64.zip
IMAGE_ZIP=$(basename $IMAGE_LINK)
if [ ! -f "$IMAGE_ZIP" ]; then
   wget -nv $IMAGE_LINK
fi
unzip -o $IMAGE_ZIP
IMAGE_NAME=${IMAGE_ZIP%.zip}.img

docker run --privileged --rm \
  -e MOUNT="/raspios-k8s" \
  -e SOURCE_IMAGE="/raspios-k8s/${IMAGE_NAME}" \
  -e SCRIPT="/raspios-k8s/setup.sh" \
  -e ADD_DATA_PART="false" \
  --mount type=bind,source="$(pwd)",destination=/raspios-k8s \
  lumastar/raspbian-customiser:local-test

# Rename the image and export the name for use with other scripts.
export RASPIOS_K8S_IMAGE_NAME="${IMAGE_NAME%.img}.raspios-k8s.img"
mv $IMAGE_NAME $RASPIOS_K8S_IMAGE_NAME
