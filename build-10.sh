#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
    echo "root is required"
    exit 1
fi

mkdir -p output
podman pull oci.heliumos.org/heliumos/bootc:10
podman run \
    --rm \
    -it \
    --pull=newer \
    --privileged \
    --security-opt label=type:unconfined_t \
    -v ./10/config.toml:/config.toml:ro \
    -v ./output:/output \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    ghcr.io/centos-workstation/bootc-image-builder:latest \
    --type anaconda-iso \
    --local \
    oci.heliumos.org/heliumos/bootc:10

chmod 777 ./output/bootiso/install.iso

podman run \
    --rm \
    -it \
    --pull=newer \
    --privileged \
    -v ./output:/output \
    -v ./10:/10 \
    oci.heliumos.org/heliumos/bootc:10 \
    bash -c '\
        dnf install -y lorax \
	&& rm -rf /images && mkdir /images \
	&& rm /output/HeliumOS-10-latest-x86_64-boot.iso || true \
	&& cd /10/product && find . | cpio -c -o | gzip -9cv > /images/product.img && cd / \
        && mkksiso --add images --volid heliumos-boot /output/bootiso/install.iso /output/HeliumOS-10-latest-x86_64-boot.iso'
