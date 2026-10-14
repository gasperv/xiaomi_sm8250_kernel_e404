#!/usr/bin/env bash
# Build the alioth kernel and package it with AnyKernel3.
# usage: build.sh <kernel-tree> <anykernel-dir> <dist-dir>
# The compiler (Neutron Clang) must be first on PATH. Produces four identically
# hashed zips in <dist-dir>; the AnyKernel installer picks EFFCPU / undervolted
# GPU dtb from the zip filename, so the user never has to rename anything.
set -euo pipefail

KDIR=$(realpath "$1")
AK=$(realpath "$2")
DIST=$(realpath -m "$3")
OUT=$KDIR/out

cd "$KDIR"
export ARCH=arm64 SUBARCH=arm64 KBUILD_BUILD_USER=build-user KBUILD_BUILD_HOST=build-host
F=(-j"$(nproc)" O="$OUT" CC=clang HOSTCC=gcc HOSTCXX=g++
   CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
   LLVM=1 LLVM_IAS=1 LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy
   OBJDUMP=llvm-objdump STRIP=llvm-strip)

make "${F[@]}" vendor/alioth_defconfig >/dev/null
# KALLSYMS off, as in the RE404 release builds
sed -i '/CONFIG_KALLSYMS=/c\CONFIG_KALLSYMS=n' "$OUT/.config"
sed -i '/CONFIG_KALLSYMS_BASE_RELATIVE=/c\CONFIG_KALLSYMS_BASE_RELATIVE=n' "$OUT/.config"

start=$(date +%s)
set +e
make "${F[@]}" 2>&1 | tee "$OUT/build.log" | grep -E --line-buffered "error:|warning:|Error [0-9]"
rc=${PIPESTATUS[0]}
set -e
echo "build exit $rc after $(( $(date +%s) - start ))s"
[ "$rc" -eq 0 ] || exit "$rc"

BOOT=$OUT/arch/arm64/boot
if [ -x ./mkdtb_uv.sh ]; then ./mkdtb_uv.sh "$OUT"; fi

# Sanity checks: root and hiding must actually be in the image
strings "$OUT/vmlinux" > "$OUT/vmlinux.strings"
grep "^Linux version 4.19" "$OUT/vmlinux.strings"
grep -m2 -E "version (code|name):" "$OUT/build.log" || true
grep -E '^CONFIG_(KSU|KSU_SUSFS|BBG|NOMOUNT)=' "$OUT/.config"
grep -E "@ReSukiSU|susfs is initialized" "$OUT/vmlinux.strings"
grep -q "@ReSukiSU" "$OUT/vmlinux.strings" || { echo "ReSukiSU missing from vmlinux"; exit 1; }
grep -q "susfs is initialized" "$OUT/vmlinux.strings" || { echo "SUSFS missing from vmlinux"; exit 1; }

cp "$BOOT/Image" "$AK/ALIOTH-Image"
cp "$BOOT/dtb" "$AK/ALIOTH-dtb"
cp "$BOOT/dtbo.img" "$AK/ALIOTH-dtbo.img"
if [ -f "$BOOT/dtb-uv" ]; then cp "$BOOT/dtb-uv" "$AK/ALIOTH-dtb-uv"; fi

name=RE404-BPF-NEXT-NEUTRON-ALIOTH-$(date -u +%y%m%d)-$(git rev-parse --short=9 HEAD)
mkdir -p "$DIST"
(cd "$AK" && zip -r9q "$DIST/$name.zip" META-INF tools ALIOTH-* anykernel.sh)
for v in -EFFCPU -uv -EFFCPU-uv; do cp "$DIST/$name.zip" "$DIST/$name$v.zip"; done
(cd "$DIST" && sha256sum "$name.zip" | tee SHA256SUMS)
echo "name=$name" >> "${GITHUB_OUTPUT:-/dev/null}"
