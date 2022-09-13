#!/bin/sh

sudo openocd \
    -f arty.cfg \
    -f /usr/share/openocd/scripts/cpld/xilinx-xc7.cfg \
    -c "adapter speed 1000; init; xc7_program xc7.tap; pld load 0 ../outputs/arty.bit; exit"

