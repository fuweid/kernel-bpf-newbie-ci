### 1. Build kernel

For example, my kernel code is in `/home/fuwei/workspace/linux`.

```bash
$ KERNEL_REPO_ROOT=/home/fuwei/workspace/linux ./build_kernel/build.sh
```

> NOTE: Current `build_kernel/config-latest.x86_64` is based on v6.5 and disable
`CONGIF_PREEMPT_RCU`.

### 2. Build rootfs

```bash
$ sudo ./rootfs/mkrootfs_ubuntu.sh
```

After build, you will have rootfs zstd tar in ./.workspace/libbpf-vmtest-rootfs-$.tar.zst

### 3. Build image

After second step, we have rootfs `./.workspace/libbpf-vmtest-rootfs-2024.05.30.tar.zst`.
```bash
$ KERNEL_REPO_ROOT=/home/fuwei/workspace/linux ROOTFS_ZSTD_TAR_PATH=./.workspace/libbpf-vmtest-rootfs-2024.05.30.tar.zst sudo -E bash -x ./build_image/build.sh
```

After build, you will have rootfs in `./.workspace/root.img`.

### 4. Run qemu

Assume that you're using x86

```
$ sudo VMLINUZ_PATH=/home/fuwei/workspace/linux/arch/x86_64/boot/bzImage  IMAGE_PATH=./.workspace/root.img ./run_qemu/run.sh
```
