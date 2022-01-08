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


source ${REPO_BASE}/helper.sh


travis_fold start build_selftests "Building bpf selftests in ${KERNEL_REPO_ROOT}"

cd "${KERNEL_REPO_ROOT}"

# Ubuntu requirements:
#
# need python(3)-docutils for rst2man
# need libcap-dev
#
make \
	CLANG=clang-${LLVM_VER} \
	LLC=llc-${LLVM_VER} \
  LLVM_STRIP=llvm-strip-${LLVM_VER} \
  VMLINUX_BTF="${KERNEL_REPO_ROOT}/vmlinux" \
  VMLINUX_H= \
  -C "tools/testing/selftests/bpf" \
  -j 4

rm -rf "${WORKSPACE}/selftests"

mkdir -p "${WORKSPACE}/selftests"

cp -R "${KERNEL_REPO_ROOT}/tools/testing/selftests/bpf" \
  "${WORKSPACE}/selftests"

travis_fold end build_selftests
