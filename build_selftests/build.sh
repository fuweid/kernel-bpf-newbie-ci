#!/bin/bash
#
# Required ENV
#
# KERNEL_REPO_ROOT: it is path about linux kernel repo.
#
# Based on https://github.com/libbpf/libbpf/commit/7e89be4022f639061dbeae9e8d3a42a20836ec05

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
cd ..

readonly LLVM_VER=14
readonly REPO_BASE="$(pwd -P)"
readonly WORKSPACE="${REPO_BASE}/.workspace"

# FIXME(fuweid):
#
# The BTF requires new version(v1.23) of pahole, which has to build with
#
# * sed -i 's/DDWARVES_MINOR_VERSION=21/DDWARVES_MINOR_VERSION=22/' CMakeLists.txt
# * cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -D__LIB=lib ..
#
# The LD_LIBRARY_PATH needs to be added with /usr/local/lib.
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}:/usr/local/lib

source ${REPO_BASE}/helper.sh

travis_fold start build_selftests "Building bpf selftests in ${KERNEL_REPO_ROOT}"

cd "${KERNEL_REPO_ROOT}"

# Ubuntu requirements:
#
# need python(3)-docutils for rst2man
# need libcap-dev
#
make -C "tools/testing/selftests/bpf" clean

make \
	CLANG=clang-${LLVM_VER} \
	LLC=llc-${LLVM_VER} \
  LLVM_STRIP=llvm-strip-${LLVM_VER} \
  VMLINUX_BTF="${KERNEL_REPO_ROOT}/vmlinux" \
  VMLINUX_H= \
  -C "tools/testing/selftests/bpf" \
  -j $(nproc)

rm -rf "${WORKSPACE}/selftests"

mkdir -p "${WORKSPACE}/selftests"

cp -R "${KERNEL_REPO_ROOT}/tools/testing/selftests/bpf" \
  "${WORKSPACE}/selftests"

travis_fold end build_selftests
