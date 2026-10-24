# cmake file for Pico 2 compatible boards with 16MB GD25Q127C flash

# Use the board header in this directory, which sets 16MB flash and
# otherwise inherits everything from the official pico2 board header.
list(APPEND PICO_BOARD_HEADER_DIRS ${MICROPY_BOARD_DIR})
set(PICO_BOARD "pico2_16mb")

# XIP setup for GD25Q127C flash: sets the QE bit via command 0x31.
set(PICO_DEFAULT_BOOT_STAGE2_FILE ${MICROPY_BOARD_DIR}/boot2_gd25q127c.S)

if(NOT DEFINED MICROPY_HW_FLASH_STORAGE_BYTES)
    set(MICROPY_HW_FLASH_STORAGE_BYTES 14680064)  # 16MB flash - 2MB firmware = 14MB filesystem
endif()
