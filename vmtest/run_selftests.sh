#!/bin/bash
#
# Required ENV
#
# BPF_SELFTESTS_PATH: it is path about build bpf-selftests suite.
#
# Based on https://github.com/libbpf/libbpf/commit/7e89be4022f639061dbeae9e8d3a42a20836ec05

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
readonly REPO_BASE="$(pwd -P)"

source "${REPO_BASE}/helper.sh"

read_lists() {
	(for path in "$@"; do
		if [[ -s "$path" ]]; then
			cat "$path"
		fi;
	done) | cut -d'#' -f1 | tr -s ' \t\n' ','
}

readonly STATUS_FILE=/exitstatus
readonly BLACKLIST=$(read_lists "${REPO_BASE}/blacklist/BLACKLIST")

test_progs() {
  cd "${BPF_SELFTESTS_PATH}"

	travis_fold start test_progs "Testing test_progs"
	# "&& true" does not change the return code (it is not executed
	# if the Python script fails), but it prevents exiting on a
	# failure due to the "set -e".
	./test_progs ${BLACKLIST:+-d$BLACKLIST} && true
	echo "test_progs:$?" >> "${STATUS_FILE}"
	travis_fold end test_progs

	travis_fold start test_progs-no_alu32 "Testing test_progs-no_alu32"
	./test_progs-no_alu32 ${BLACKLIST:+-d$BLACKLIST} && true
	echo "test_progs-no_alu32:$?" >> "${STATUS_FILE}"
	travis_fold end test_progs-no_alu32
}

test_maps() {
  cd "${BPF_SELFTESTS_PATH}"

	travis_fold start test_maps "Testing test_maps"
	./test_maps && true
	echo "test_maps:$?" >> "${STATUS_FILE}"
	travis_fold end test_maps
}

test_verifier() {
  cd "${BPF_SELFTESTS_PATH}"

	travis_fold start test_verifier "Testing test_verifier"
	./test_verifier && true
	echo "test_verifier:$?" >> "${STATUS_FILE}"
	travis_fold end test_verifier
}

test_progs
test_maps
test_verifier
