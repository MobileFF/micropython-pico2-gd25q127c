#!/bin/sh
# Build MicroPython for a Pico 2 compatible board with GD25Q127C 16MB flash.
#
# Usage: ./build.sh /path/to/micropython [RISCV]
#
# The board definition stays in this repository; MicroPython's rp2 port picks
# it up through BOARD_DIR, so the MicroPython checkout itself is not modified.
# Output: <micropython>/ports/rp2/build-PICO2_GD25Q127C[-RISCV]/firmware.uf2

set -e

if [ -z "$1" ]; then
    echo "usage: $0 /path/to/micropython [RISCV]" >&2
    exit 1
fi

MPY_DIR=$(cd "$1" && pwd)
BOARD_DIR=$(cd "$(dirname "$0")/boards/PICO2_GD25Q127C" && pwd)
VARIANT_ARG=
if [ -n "$2" ]; then
    VARIANT_ARG="BOARD_VARIANT=$2"
fi
JOBS=$(nproc 2>/dev/null || echo 4)

make -C "$MPY_DIR/mpy-cross" -j"$JOBS"
make -C "$MPY_DIR/ports/rp2" BOARD_DIR="$BOARD_DIR" $VARIANT_ARG submodules
make -C "$MPY_DIR/ports/rp2" BOARD_DIR="$BOARD_DIR" $VARIANT_ARG -j"$JOBS"
