#!/usr/bin/env bash
# Build the GPU-undervolt dtb (kona-v2.1-uv.dts) next to the regular one.
# usage: ./mkdtb_uv.sh [out-dir] [dts-name]   (defaults: out, kona-v2.1-uv)
# Run after a normal build, with the same clang on PATH. The result goes to
# <out>/arch/arm64/boot/dtb-uv. It is compiled outside <out>/arch/arm64/boot/dts
# on purpose: arch/arm64/boot/Makefile concatenates every *.dtb found there
# into the regular dtb.
set -e
OUT=$(realpath "${1:-out}")
NAME=${2:-kona-v2.1-uv}
SRC=$(realpath "$(dirname "$0")")
DTS=$SRC/arch/arm64/boot/dts/vendor/qcom
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
clang -E -nostdinc -I"$SRC/scripts/dtc/include-prefixes" -undef -D__DTS__ \
	-x assembler-with-cpp -o "$TMP/$NAME.dts.tmp" "$DTS/$NAME.dts"
"$OUT/scripts/dtc/dtc" -q -O dtb -o "$TMP/$NAME.dtb" -b 0 -i"$DTS/" \
	-i"$SRC/scripts/dtc/include-prefixes" -@ -Wno-interrupt_provider \
	-Wno-unit_address_vs_reg -Wno-simple_bus_reg -Wno-unit_address_format \
	-Wno-avoid_unnecessary_addr_size -Wno-alias_paths \
	-Wno-graph_child_address -Wno-graph_port -Wno-unique_unit_address \
	-Wno-pci_device_reg "$TMP/$NAME.dts.tmp"
cp "$TMP/$NAME.dtb" "$OUT/arch/arm64/boot/dtb-${NAME##*-}"
echo "$OUT/arch/arm64/boot/dtb-${NAME##*-}"
