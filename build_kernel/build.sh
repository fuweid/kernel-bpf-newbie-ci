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

readonly REPO_BASE="$(pwd -P)"
source ${REPO_BASE}/helper.sh


travis_fold start build_kernel "Building kernel in ${KERNEL_REPO_ROOT}"

cd "${KERNEL_REPO_ROOT}"
cp "${REPO_BASE}/build_kernel/config-latest.x86_64" .config

make olddefconfig && make prepare
make -j 4 all

travis_fold end build_kernel
