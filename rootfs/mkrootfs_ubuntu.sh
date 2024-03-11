#!/bin/bash
#
# This script builds a Ubuntu root filesystem image for testing libbpf in a
# virtual machine. Requires debootstrap >= 1.0.95 and zstd.
#
# Based on https://github.com/libbpf/libbpf/commit/7e89be4022f639061dbeae9e8d3a42a20836ec05

set -euox pipefail

# Check whether we are root now in order to avoid confusing errors later.
if [ "$(id -u)" != 0 ]; then
	echo "$0 must run as root" >&2
	exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")"
cd ..
readonly REPO_BASE="$(pwd -P)"
readonly WORKSPACE="${REPO_BASE}/.workspace"

mkdir -p "${WORKSPACE}"
cd "${WORKSPACE}"

# Create a working directory and schedule its deletion.
root=$(mktemp -d -p "$PWD")
trap 'rm -r "$root"' EXIT

# Install packages.
packages=binutils,coreutils,busybox-static,elfutils,iproute2,libcap2,libelf1,strace,zlib1g,sudo

debootstrap \
  --include="$packages" \
  --variant=minbase \
  focal "$root" \
  "https://mirrors.tuna.tsinghua.edu.cn/ubuntu/"

# Remove the init scripts (tests use their own). Also remove various
# unnecessary files in order to save space.
rm -rf \
	"$root"/etc/rcS.d \
	"$root"/usr/share/{doc,info,locale,man,zoneinfo} \
	"$root"/var/cache/apt/archives/* \
	"$root"/var/lib/apt/lists/*

# Apply common tweaks.
${REPO_BASE}/rootfs/mkrootfs_tweak.sh "$root"

# Save the result.
name="libbpf-vmtest-rootfs-$(date +%Y.%m.%d).tar.zst"
rm -f "$name"
tar -C "$root" -c . | zstd -T0 -19 -o "$name"
