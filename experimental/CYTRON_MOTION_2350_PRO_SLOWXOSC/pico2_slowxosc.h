// Same as the SDK's pico2 board header, but waits longer for the crystal
// oscillator to start (x64 instead of the SDK default x6), as CircuitPython
// does for this board (ports/raspberrypi/boards/cytron_motion_2350_pro/
// pico-sdk-configboard.h). For boards that boot after a warm reset but not
// after a power cycle or RUN/reset button press.
#ifndef _BOARDS_PICO2_SLOWXOSC_H
#define _BOARDS_PICO2_SLOWXOSC_H
#ifndef PICO_XOSC_STARTUP_DELAY_MULTIPLIER
#define PICO_XOSC_STARTUP_DELAY_MULTIPLIER 64
#endif
#include "boards/pico2.h"
#endif
