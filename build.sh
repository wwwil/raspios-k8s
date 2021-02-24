#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

IMAGE_LINK_ARM64=https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2020-08-24/2020-08-20-raspios-buster-arm64-lite.zip
IMAGE_LINK_ARMHF=https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2020-08-24/2020-08-20-raspios-buster-armhf-lite.zip

ARCH=arm64
if [ $# != 0 ]; then
    ARCH=$1
fi

case $ARCH in
    arm64 )
        IMAGE_LINK=$IMAGE_LINK_ARM64
        ;;
    armhf )
        IMAGE_LINK=$IMAGE_LINK_ARMHF
        ;;
    * )
        echo "Arch \"$ARCH\" not supported..."
        exit 1
        ;;
esac

IMAGE_ZIP=$(basename $IMAGE_LINK)
if [ ! -f "$IMAGE_ZIP" ]; then
   wget -nv $IMAGE_LINK
fi
unzip -o $IMAGE_ZIP
IMAGE_NAME=${IMAGE_ZIP%.zip}.img

SKYDOCK_IMAGE="quay.io/wwwil/skydock:v0.3.0"
docker pull ${SKYDOCK_IMAGE}
docker run --privileged --rm \
  -e MOUNT="/raspios-k8s" \
  -e SOURCE_IMAGE="/raspios-k8s/${IMAGE_NAME}" \
  -e SCRIPT="/raspios-k8s/setup.sh" \
  -e ARCH="${ARCH}" \
  -e ADD_DATA_PART="false" \
  -e EXPAND=800 \
  --mount type=bind,source="$(pwd)",destination=/raspios-k8s \
  ${SKYDOCK_IMAGE}

# Rename the image and export the name for use with other scripts.
export RASPIOS_K8S_IMAGE_NAME="${IMAGE_NAME%.img}.raspios-k8s.img"
mv $IMAGE_NAME $RASPIOS_K8S_IMAGE_NAME
