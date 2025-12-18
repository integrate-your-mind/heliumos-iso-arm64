#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BOOTC_REPO_URL="https://codeberg.org/HeliumOS/bootc.git"
BOOTC_REF="release"

BOOTC_IMG_BUILDER_IMAGE="ghcr.io/centos-workstation/bootc-image-builder:latest"
BOOTC_BASE_OS_IMAGE="quay.io/centos/centos:stream10"

LOCAL_BOOTC_IMAGE_TAG="localhost/heliumos-bootc:10-arm64"

OUT_DIR="${ROOT_DIR}/output/arm64"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

require_cmd docker
require_cmd git

mkdir -p "${OUT_DIR}"

if [[ ! -d "${ROOT_DIR}/bootc/.git" ]]; then
  echo "Cloning bootc sources into ./bootc ..."
  rm -rf "${ROOT_DIR}/bootc"
  git clone "${BOOTC_REPO_URL}" "${ROOT_DIR}/bootc"
  git -C "${ROOT_DIR}/bootc" checkout "${BOOTC_REF}"
else
  echo "Using existing ./bootc checkout"
fi

echo "Creating/reusing docker volumes for podman+osbuild caches..."
docker volume create helium_podman_storage >/dev/null
docker volume create helium_osbuild_store >/dev/null
docker volume create helium_rpmmd_cache >/dev/null

echo "Building ARM64 HeliumOS bootc container image (${LOCAL_BOOTC_IMAGE_TAG})..."
docker run --rm --privileged \
  -v helium_podman_storage:/var/lib/containers/storage \
  -v "${ROOT_DIR}/bootc:/src:ro" \
  --entrypoint bash \
  "${BOOTC_IMG_BUILDER_IMAGE}" \
  -lc "podman build --network=host -t '${LOCAL_BOOTC_IMAGE_TAG}' -f /src/10/Containerfile /src"

echo "Generating anaconda-iso manifest..."
docker run --rm --privileged \
  -v helium_podman_storage:/var/lib/containers/storage \
  -v "${ROOT_DIR}/10/config.toml:/config.toml:ro" \
  -v "${OUT_DIR}:/output" \
  --entrypoint bash \
  "${BOOTC_IMG_BUILDER_IMAGE}" \
  -lc "bootc-image-builder manifest --type anaconda-iso --target-arch aarch64 '${LOCAL_BOOTC_IMAGE_TAG}' > /output/manifest-anaconda-iso.json"

echo "Patching manifest (work around missing dracut rngd module deps)..."
docker run --rm \
  -v "${OUT_DIR}:/output" \
  --entrypoint python3 \
  "${BOOTC_IMG_BUILDER_IMAGE}" \
  - <<'PY'
import json
from pathlib import Path

path = Path("/output/manifest-anaconda-iso.json")
data = json.loads(path.read_text())

for pipeline in data.get("pipelines", []):
    for stage in pipeline.get("stages", []):
        if stage.get("type") != "org.osbuild.dracut":
            continue
        opts = stage.get("options", {})
        modules = opts.get("modules")
        if isinstance(modules, list) and "rngd" in modules:
            opts["modules"] = [m for m in modules if m != "rngd"]

path.write_text(json.dumps(data, separators=(",", ":")))
PY

echo "Building ISO via osbuild (this can take a while)..."
docker run --rm --privileged \
  -v helium_podman_storage:/var/lib/containers/storage \
  -v helium_osbuild_store:/store \
  -v helium_rpmmd_cache:/rpmmd \
  -v "${OUT_DIR}:/output" \
  --entrypoint bash \
  "${BOOTC_IMG_BUILDER_IMAGE}" \
  -lc "osbuild --store /store --output-directory /output --export bootiso /output/manifest-anaconda-iso.json"

echo "Branding ISO (mkksiso/product.img)..."
docker run --rm --privileged \
  -v "${OUT_DIR}:/output" \
  -v "${ROOT_DIR}/10:/10:ro" \
  --entrypoint bash \
  "${BOOTC_BASE_OS_IMAGE}" \
  -lc "set -euo pipefail; dnf -y install lorax cpio gzip >/dev/null; \
        rm -rf /images && mkdir /images; \
        rm -f /output/HeliumOS-10-latest-aarch64-boot.iso; \
        cd /10/product; find . | cpio -c -o | gzip -9cv > /images/product.img >/dev/null; \
        cd /; mkksiso --add images --volid heliumos-boot /output/bootiso/install.iso /output/HeliumOS-10-latest-aarch64-boot.iso"

echo "Done:"
echo "  ${OUT_DIR}/HeliumOS-10-latest-aarch64-boot.iso"
