#!/bin/bash
#
# Required ENV
#
# KERNEL_REPO_ROOT: it is path about linux kernel repo.
#
# ROOTFS_ZSTD_TAR_PATH: it is rootfs tarball in zstd format.
#
# Based on https://github.com/libbpf/ci/commit/18814027261905833656e2358d67530251700763

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
cd ..

# FIXME(fuweid):
#
# The BTF requires new version(v1.23) of pahole, which has to build with
#
# * sed -i 's/DDWARVES_MINOR_VERSION=21/DDWARVES_MINOR_VERSION=22/' CMakeLists.txt
# * cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -D__LIB=lib ..
#
# The LD_LIBRARY_PATH needs to be added with /usr/local/lib.
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}:/usr/local/lib

readonly REPO_BASE="$(pwd -P)"
readonly WORKSPACE="${REPO_BASE}/.workspace"
readonly KERNEL_RELEASE="$(make -C "${KERNEL_REPO_ROOT}" -s kernelrelease)"
readonly VMLINUZ_PATH="${KERNEL_REPO_ROOT}/$(make -C "$KERNEL_REPO_ROOT" -s image_name)"
readonly PROJECT_NAME="libbpf"
readonly IMAGE_SIZE=8G
readonly IMAGE_NAME="${WORKSPACE}/root.img"

source ${REPO_BASE}/helper.sh

if [ ! -f "${ROOTFS_ZSTD_TAR_PATH}" ]; then
  echo "ENV ROOTFS_ZSTD_TAR_PATH is required" >&2
  exit 2
fi

rm -f "${IMAGE_NAME}"

# Create a working directory and schedule its deletion.
working_dir=$(mktemp -d -p "${WORKSPACE}")

cleanup() {
  rm -rf "${working_dir}"
	guestfish --remote exit 2>/dev/null || true
}
trap cleanup EXIT

set_nocow() {
	touch "$@"
	chattr +C "$@" >/dev/null 2>&1 || true
}

cp_img() {
	set_nocow "$2"
	cp --reflink=auto "$1" "$2"
}

create_rootfs_img() {
	local path="$1"

	set_nocow "${path}"
	truncate -s "${IMAGE_SIZE}" "${path}"
	mkfs.ext4 -q "${path}"
}

tar_in() {
	local dst_path="$1"

	# guestfish --remote does not forward file descriptors, which prevents
	# us from using `tar-in -` or bash process substitution. We don't want
	# to copy all the data into a temporary file, so use a FIFO.
	local tmp=$(mktemp -d -p ${working_dir})

	mkfifo "${tmp}/fifo"
	cat >"${tmp}/fifo" &
	local cat_pid=$!

	guestfish --remote tar-in "${tmp}/fifo" "${dst_path}"
	wait "${cat_pid}"
	rm -r "${tmp}"
}

travis_fold start vmlinux_setup "Preparing Linux image for ${KERNEL_RELEASE}"

# Mount and set up the rootfs image. Use a persistent guestfish session in
# order to avoid the startup overhead.
# Work around https://bugs.launchpad.net/fuel/+bug/1467579.
sudo chmod +r /boot/vmlinuz* || true
eval "$(guestfish --listen)"

create_rootfs_img "${IMAGE_NAME}"
guestfish --remote \
	add "${IMAGE_NAME}" label:img : \
	launch : \
	mount /dev/disk/guestfs/img /
  cat "${ROOTFS_ZSTD_TAR_PATH}" | zstd -d | tar_in /

# Install vmlinux.
echo "Copying vmlinux..." >&2
guestfish --remote \
	upload "${KERNEL_REPO_ROOT}/vmlinux" "/boot/vmlinux-${KERNEL_RELEASE}" : \
	chmod 644 "/boot/vmlinux-${KERNEL_RELEASE}"

travis_fold end vmlinux_setup

travis_fold start copy_files "Copying files..."

# Copy the source files in.
guestfish --remote \
	mkdir-p "/${PROJECT_NAME}" : \
	chmod 0755 "/${PROJECT_NAME}"

init_script_tmp=$(mktemp -p ${working_dir})
cat <<HERE >"${init_script_tmp}"
#!/bin/sh

bash
HERE

guestfish --remote \
	upload "${init_script_tmp}" /etc/rcS.d/S50-run-tests : \
	chmod 755 /etc/rcS.d/S50-run-tests

# TODO: copy your binary into it.
#guestfish --remote \
#	upload /home/fuwei/workspace/rcudeadlock/rcudeadlock /rcudeadlock : \
#	chmod 755 /rcudeadlock

shutdown_script_tmp=$(mktemp -p ${working_dir})
cat <<HERE >"${shutdown_script_tmp}"
#!/bin/sh

poweroff
HERE

guestfish --remote \
	upload "${shutdown_script_tmp}" /etc/rcS.d/S99-poweroff : \
	chmod 755 /etc/rcS.d/S99-poweroff

guestfish --remote exit

travis_fold end copy_files
