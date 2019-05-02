# Arty starter project

A project template for the [Arty FPGA development board](https://store.digilentinc.com/arty-a7-artix-7-fpga-development-board-for-makers-and-hobbyists/).

Uses Vivado "non-project" mode. This means it is built entirely from the command line. There is no need to open the Vivado GUI. 

Building is as easy as:
```
vivado -mode batch -nojournal -source compile.tcl
```

## Functionality
* System clock + buffer
* GPIO (switches, buttons, LEDs)
* 100M Ethernet
* VIOs (Virtual IOs)
* Chipscope
* Xilinx XPM modules

The design flashes the LEDs in a pattern determined by the switches and buttons. It also loops back the packets received on the Ethernet port. 

The signals from the Ethernet phy RX side are captured by chipscope and the packet rx count is available from the VIO.

## See also

https://github.com/ZipCPU/openarty

