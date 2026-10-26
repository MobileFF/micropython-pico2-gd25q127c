// Same as the SDK's pico2 board header, but with a 37.5MHz flash clock
// (150MHz / 4) instead of 75MHz, for boards whose flash chip is not
// reliable at 75MHz. Flash size stays at pico2's 4MB.
#ifndef _BOARDS_PICO2_SLOWFLASH_H
#define _BOARDS_PICO2_SLOWFLASH_H
#ifndef PICO_FLASH_SPI_CLKDIV
#define PICO_FLASH_SPI_CLKDIV 4
#endif
#include "boards/pico2.h"
#endif
