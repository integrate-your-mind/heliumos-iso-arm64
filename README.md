# HeliumOS installer ISO

Build scripts/config for the HeliumOS 10 Anaconda installer ISO (bootc-based).

## ARM64 / Apple Silicon (Parallels)

HeliumOS does not currently publish an official ARM64 installer ISO; this repo can build an **experimental** `aarch64` ISO from source.

- Build: `./build-10-arm64-docker.sh`
- Output: `output/arm64/HeliumOS-10-latest-aarch64-boot.iso`

## Notes

- The repository does **not** commit ISOs (they’re large). Publish/download them via GitHub Releases or other artifact hosting.
