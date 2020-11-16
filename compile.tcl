#Compile TCL script for Arty project template

#Outputs go in outputs directory
set ::output_dir "./outputs"
file mkdir $::output_dir

#Create the project
create_project -part xc7a35ticsg324-1l -in_memory 

#Read the sources
read_verilog -quiet [glob -nocomplain -directory src *.v]
read_vhdl    -quiet [glob -nocomplain -directory src *.vhdl]
read_xdc src/arty.xdc

#Synthesize the design
synth_design -top top -flatten_hierarchy rebuilt
write_checkpoint -force "${::output_dir}/post_synth.dcp"

#Continue with implementation
opt_design
write_checkpoint -force "${::output_dir}/post_opt.dcp"

place_design -directive Explore
write_checkpoint -force "${::output_dir}/post_place.dcp"

phys_opt_design -directive AggressiveExplore
write_checkpoint -force "${::output_dir}/post_phys_opt.dcp"

route_design -directive Explore -tns_cleanup
write_checkpoint -force "${::output_dir}/post_route.dcp"

phys_opt_design -directive Explore
write_checkpoint -force "${::output_dir}/post_route_phys_opt.dcp"

#Reports
report_clocks -file "${::output_dir}/clocks.rpt"
report_timing_summary -file "${::output_dir}/timing.rpt"
report_utilization -file "${::output_dir}/utilization.rpt"

set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR NO [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CCLKPIN PULLNONE [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

#Outputs
write_bitstream "${::output_dir}/arty.bit" -force

#Flash image
write_cfgmem -format mcs -interface spix4 -size 16 \
	-loadbit "up 0 ${::output_dir}/arty.bit" \
	-file ${::output_dir}/arty.mcs -force
