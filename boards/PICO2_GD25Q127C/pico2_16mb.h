// Pico 2 compatible board with 16MB flash.
// Same pinout as the official Pico 2; differs in flash size (GD25Q127C) and
// uses a slower flash clock and longer crystal startup delay.

#ifndef _BOARDS_PICO2_16MB_H
#define _BOARDS_PICO2_16MB_H

pico_board_cmake_set(PICO_PLATFORM, rp2350)
pico_board_cmake_set_default(PICO_RP2350_A2_SUPPORTED, 1)

pico_board_cmake_set(PICO_FLASH_SIZE_BYTES, (16 * 1024 * 1024))
#ifndef PICO_FLASH_SIZE_BYTES
#define PICO_FLASH_SIZE_BYTES (16 * 1024 * 1024)
#endif

// Conservative flash clock: 150MHz / 4 = 37.5MHz (pico2.h uses 2 = 75MHz).
// This also caps MicroPython's runtime flash clock (MICROPY_HW_FLASH_MAX_FREQ).
#ifndef PICO_FLASH_SPI_CLKDIV
#define PICO_FLASH_SPI_CLKDIV 4
#endif

// Allow for slow-starting crystals on third-party boards (SDK default is 6).
#ifndef PICO_XOSC_STARTUP_DELAY_MULTIPLIER
#define PICO_XOSC_STARTUP_DELAY_MULTIPLIER 64
#endif

#include "boards/pico2.h"

#endif
