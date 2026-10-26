# Cytron MOTION 2350 Pro, test build: official board definition with only
# the crystal oscillator startup delay raised to x64 (see pico2_slowxosc.h).
list(APPEND PICO_BOARD_HEADER_DIRS ${MICROPY_BOARD_DIR})
set(PICO_BOARD "pico2_slowxosc")
if(NOT DEFINED MICROPY_HW_FLASH_STORAGE_BYTES)
    set(MICROPY_HW_FLASH_STORAGE_BYTES 1048576)  # 1024 * 1024
endif()
