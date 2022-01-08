#!/bin/bash
#
#
# Optional ENV(s):
#
# NPROC: The number of CPUs, default is $(nproc)
#
#
# Required ENV(s):
#
# IMAGE_PATH: It is the path about rootfs image.
#
# VMLINUZ_PATH: It is the vmlinuz about kernel.
#
# Based on https://github.com/libbpf/ci/commit/18814027261905833656e2358d67530251700763

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
cd ..

readonly REPO_BASE="$(pwd -P)"
source ${REPO_BASE}/helper.sh

trap 'exit 2' ERR

travis_fold start vm_init "Starting virtual machine..."

NPROC="${NPROC:-$(nproc)}"
echo "Starting VM with ${NPROC} CPUs..."

APPEND=${APPEND:-}

qemu="qemu-system-x86_64"
console="ttyS0,115200"
smp=${NPROC}
kvm_accel="-cpu kvm64 -enable-kvm"
tcg_accel="-cpu qemu64 -machine accel=tcg"

if kvm-ok ; then
  accel=$kvm_accel
else
  accel=$tcg_accel
fi

"$qemu" -nodefaults --no-reboot -display none -serial mon:stdio \
  ${accel} -smp "$smp" -m 8G \
  -drive file="${IMAGE_PATH}",format=raw,index=1,media=disk,if=virtio,cache=none \
  -kernel "${VMLINUZ_PATH}" -append "root=/dev/vda rw console=$console panic=-1 $APPEND"

exitfile="$(guestfish --ro -a "${IMAGE_PATH}" -i cat /exitstatus 2>/dev/null)"
exitstatus="$(echo -e "$exitfile" | awk --field-separator ':' \
  'BEGIN { s=0 } { if ($2) {s=1} } END { print s }')"

if [[ "$exitstatus" =~ ^[0-9]+$ ]]; then
  printf '\nTests exit status: %s\n' "$exitstatus" >&2
else
  printf '\nCould not read tests exit status ("%s")\n' "$exitstatus" >&2
  exitstatus=1
fi

travis_fold end shutdown

# Final summary - Don't use a fold, keep it visible
echo -e "\033[1;33mTest Results:\033[0m"
echo -e "$exitfile" | while read result; do
  testgroup=${result%:*}
  status=${result#*:}
  # Print final result for each group of tests
  if [[ "$status" -eq 0 ]]; then
    printf "%20s: \033[1;32mPASS\033[0m\n" "$testgroup"
  else
    printf "%20s: \033[1;31mFAIL\033[0m (returned %s)\n" "$testgroup" "$status"
  fi
done

shutdownstatus="$(guestfish --ro -a "$IMAGE_PATH" -i cat /shutdown-status 2>/dev/null)"
if [[ "${shutdownstatus}" == "clean" ]]; then
    printf "%20s: \033[1;32mCLEAN\033[0m\n" "shutdown"
else
    printf "%20s: \033[1;31mNOT CLEAN\033[0m" "shutdown"
    exitstatus=1
fi

exit "$exitstatus"
