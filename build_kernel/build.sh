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

# FIXME(fuweid):
#
# The BTF requires new version(v1.23) of pahole, which has to build with
#
# * sed -i 's/DDWARVES_MINOR_VERSION=21/DDWARVES_MINOR_VERSION=22/' CMakeLists.txt
# * cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -D__LIB=lib ..
#
# The LD_LIBRARY_PATH needs to be added with /usr/local/lib.
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}:/usr/local/lib

travis_fold start build_kernel "Building kernel in ${KERNEL_REPO_ROOT}"

cd "${KERNEL_REPO_ROOT}"
cp "${REPO_BASE}/build_kernel/config-latest.x86_64" .config

# make clean
make olddefconfig
make prepare
make -j $(nproc) all

travis_fold end build_kernel
