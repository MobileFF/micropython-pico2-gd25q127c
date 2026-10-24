# MicroPython for Pico 2 compatible boards with GD25Q127C 16MB flash

[日本語版はこちら (Japanese)](README_ja.md)

A MicroPython board definition for third-party RP2350 boards that copy the
Raspberry Pi Pico 2 pinout but carry a **GigaDevice GD25Q127C** 16MB flash
chip (package marking `25q127cs16`).

On these boards the official MicroPython UF2 for the Pico 2 **never boots**:
no USB CDC device appears and no `/dev/ttyACM0` is created, even though
CircuitPython's `raspberry_pi_pico2` build runs fine. This repository fixes
that and also makes the full 16MB of flash available.

## Symptoms this fixes

- After copying the official `RPI_PICO2` UF2, the `RP2350` drive disappears
  (the board resets) but no serial port ever shows up.
- The board is not even listed as a USB device on the host.
- CircuitPython works on the same board.

## Root cause

The official Pico 2 board definition runs the flash at **75MHz**
(150MHz / `PICO_FLASH_SPI_CLKDIV 2`). This is used both by the second stage
bootloader (boot2) and later by MicroPython itself when it retunes the flash
timing (`rp2_flash_set_timing()` in `ports/rp2/rp2_flash.c`). The GD25Q127C on
these boards does not run reliably at that speed. Lowering the clock to
**37.5MHz** (`PICO_FLASH_SPI_CLKDIV 4`) is what makes the board boot.

See [How this was found](#how-this-was-found) for the test matrix.

## What this board definition changes

| Setting | Official `RPI_PICO2` | This board (`PICO2_GD25Q127C`) |
|---|---|---|
| Flash size | 4MB | 16MB |
| Filesystem | 3MB | 14MB |
| Flash clock | 150MHz / 2 = 75MHz | 150MHz / 4 = **37.5MHz** |
| boot2 | `boot2_w25q080` (QE bit written with `0x01`) | `boot2_gd25q127c` (QE bit written with `0x31`) |
| Crystal startup delay | x6 (SDK default) | x64 |
| Extra pin names | — | `GP23`, `GP24` |

| File | Contents |
|---|---|
| `pico2_16mb.h` | pico-sdk board header: 16MB flash, `PICO_FLASH_SPI_CLKDIV 4`, `PICO_XOSC_STARTUP_DELAY_MULTIPLIER 64`; everything else is inherited from the SDK's `boards/pico2.h` |
| `boot2_gd25q127c.S` | XIP setup (boot2) for GD25Q127C, derived from pico-sdk's `boot2_w25q080.S` (see below) |
| `mpconfigboard.cmake` | Selects the header and boot2 above; 14MB filesystem (16MB - 2MB for firmware) |
| `mpconfigboard.h`, `board.json`, `pins.csv`, variants | Based on MicroPython's `RPI_PICO2`, with the board name changed and `GP23`/`GP24` added |

### boot2_gd25q127c.S vs. boot2_w25q080.S

- The status register write that enables Quad mode is changed from
  `0x01 00 02` (write SR1 and SR2 together) to `0x31 02` (write SR2 only).
  The GD25Q127C datasheet specifies `0x31` for writing SR2, so the W25Q080
  sequence is not expected to set the QE bit on this chip.
- Only the QE bit (SR2 bit 1) is tested, instead of comparing the whole SR2
  with `0x02`, so unrelated SR2 bits do not cause a status register write on
  every boot.
- Both the Arm and RISC-V code paths were changed. **The RISC-V path has not
  been built or tested.**

## Build

The board definition lives in this repository. MicroPython's rp2 port picks it
up through `BOARD_DIR`, so your MicroPython checkout is not modified.

Requirements: a git clone of MicroPython, `arm-none-eabi-gcc`, CMake, make and
Python 3 (the same as a normal MicroPython rp2 build).

```sh
git clone https://github.com/micropython/micropython.git
git clone <this repository> micropython-pico2-gd25q127c
cd micropython-pico2-gd25q127c
./build.sh ../micropython
# -> ../micropython/ports/rp2/build-PICO2_GD25Q127C/firmware.uf2
```

Or by hand:

```sh
cd micropython/ports/rp2
make -C ../../mpy-cross
make BOARD_DIR=/path/to/micropython-pico2-gd25q127c/boards/PICO2_GD25Q127C submodules
make BOARD_DIR=/path/to/micropython-pico2-gd25q127c/boards/PICO2_GD25Q127C
```

The filesystem size can be changed with `MICROPY_HW_FLASH_STORAGE_BYTES`:

```sh
make BOARD_DIR=... MICROPY_HW_FLASH_STORAGE_BYTES=15728640   # 15MB
```

Tested with MicroPython v1.29.0-preview.

## Install

1. Hold BOOTSEL and plug the board into USB. An `RP2350` drive appears.
2. Copy `firmware.uf2` to that drive.
3. The board reboots and a serial port (`/dev/ttyACM0` on Linux) appears.

Check that the 16MB layout is active (expected result: about `14336`):

```python
import os; s = os.statvfs('/'); print(s[0] * s[2] // 1024)
```

## Board details

| Item | Value |
|---|---|
| MCU | RP2350 (Pico 2 pinout) |
| Flash | 16MB GigaDevice GD25Q127C (marking `25q127cs16`) |
| GP23 | RGB LED |
| GP24 | Push button |
| GP25 | LED (`Pin("LED")`) |

Boards like this are sold under many names. If yours has the same flash
marking but behaves differently, please open an issue.

## How this was found

Every test firmware below was built with the x64 crystal startup delay.

| Build | boot2 | Flash clock | Result |
|---|---|---|---|
| test1 | w25q080 | 75MHz | no USB |
| test2 | gd25q127c (QE via `0x31`) | 75MHz | no USB |
| test3 | generic_03h (plain serial read) | 75MHz | no USB |
| diag1 | gd25q127c | 37.5MHz | **boots, USB CDC works, `mpremote` connects** |

All three failing builds ran the flash at 75MHz, even `generic_03h`, because
boot2 also uses `PICO_FLASH_SPI_CLKDIV`. test2 and diag1 differ only in the
clock, so lowering the clock is required.

Not yet isolated:

- whether the GD25Q127C boot2 is also required (the stock W25Q080 boot2 at
  37.5MHz was not tried); it is kept because it matches the datasheet,
- whether the longer crystal startup delay matters; it only adds tens of
  milliseconds at boot, so it is kept.

Side note: pico-sdk's `boot2_at25sf128a.S`, which also writes QE with `0x31`,
sits in the RP2350 directory but uses RP2040 SSI registers, so it cannot be
used on RP2350.

## Status

- [x] Diagnostic build (37.5MHz + GD25Q127C boot2) boots on real hardware
- [x] This board definition builds out-of-tree via `BOARD_DIR`
- [x] Release build verified on real hardware: boots, 14MB filesystem, and
      the flash does not wrap at 4/8/12MB (the full 16MB is present)
- [ ] Faster flash clocks (e.g. 150MHz / 3 = 50MHz)
- [ ] RISC-V variant (`./build.sh ../micropython RISCV`)

## License

MIT, see [LICENSE](LICENSE). `boot2_gd25q127c.S` is derived from pico-sdk and
remains under the BSD-3-Clause license stated in its header (Copyright (c)
2019-2022 Raspberry Pi (Trading) Ltd.). The other board files are based on
MicroPython's `RPI_PICO2` board definition (MIT).

This project is not affiliated with Raspberry Pi Ltd. or GigaDevice.
