module top (
    //System clock
    input        clk_100,

    //GPIO
    input  [3:0] sw,
    input  [3:0] btn,

    output [3:0] led_b,
    output [3:0] led_g,
    output [3:0] led_r,

    output [3:0] led,

    //Ethernet
    output       eth_mdc,
    inout        eth_mdio,

    output       eth_ref_clk,
    output       eth_rstn,

    input        eth_rx_clk,
    input        eth_col,
    input        eth_crs,
    //Mark some debug ports so we can see them in chipscope
    (* dont_touch = "true" *)(* mark_debug = "true" *)input        eth_rx_dv,
    (* dont_touch = "true" *)(* mark_debug = "true" *)input  [3:0] eth_rxd,
    input        eth_rxerr,

    input        eth_tx_clk,
    output       eth_tx_en,
    output [3:0] eth_txd

);

//////////////////////////////////////////////////////////////////
//Main clock buffer
//////////////////////////////////////////////////////////////////

(* keep = "true" *) wire clk_100_i;

//This buffer is necessary to prevent Vivado from shitting itself if you use
//clk_100 as the debug clk for an ILA (which can be set in compile.tcl). If
//you are using a different clock, or not using the ILA at all, this can be
//safely removed.
BUFG BUFG_inst_clk_100(
    .I(clk_100),
    .O(clk_100_i)
);

//////////////////////////////////////////////////////////////////
//GPIO
//////////////////////////////////////////////////////////////////

reg [29:0] cntr = 0;

always @(posedge clk_100_i)
    cntr <= cntr + sw;

//Display the high bits of a counter on the LEDs
assign led = cntr[29:26];

reg [29:0] cntr_colour = 0;

always @(posedge clk_100_i)
    cntr_colour <= cntr_colour + btn;

//Cycle through some colors on the RGB LEDs
assign led_b = {4{cntr_colour[29]}};
assign led_g = {4{cntr_colour[28]}};
assign led_r = {4{cntr_colour[27]}};


//////////////////////////////////////////////////////////////////
//VIO probes
//////////////////////////////////////////////////////////////////

wire [255:0] probe_in0;
wire [255:0] probe_in1;
wire [255:0] probe_in2;
wire [255:0] probe_in3;
wire [255:0] probe_out0;
wire [255:0] probe_out1;
wire [255:0] probe_out2;
wire [255:0] probe_out3;

vio_0 vio_0_inst (
    .clk(eth_rx_clk_i),

    .probe_in0(probe_in0),
    .probe_in1(probe_in1),
    .probe_in2(probe_in2),
    .probe_in3(probe_in3),

    .probe_out0(probe_out0),
    .probe_out1(probe_out1),
    .probe_out2(probe_out2),
    .probe_out3(probe_out3)
);

//////////////////////////////////////////////////////////////////
//Ethernet
//////////////////////////////////////////////////////////////////

(* keep = "true" *) wire eth_rx_clk_i;
(* keep = "true" *) wire eth_tx_clk_i;

//Ethernet clock buffers
BUFG BUFG_inst_eth_tx(
    .I(eth_tx_clk),
    .O(eth_tx_clk_i)
);

BUFG BUFG_inst_eth_rx(
    .I(eth_rx_clk),
    .O(eth_rx_clk_i)
);

assign eth_rstn = 1'b1;

wire clkfbin;
wire clkfbout;
wire locked;
wire ref_clk;

BUFG clkfb_buf (
  .O (clkfbin),
  .I (clkfbout)
);

//Generate the reference clock needed by the external Ethernet phy
MMCME2_BASE #(
  .CLKFBOUT_MULT_F      (8),
  .DIVCLK_DIVIDE        (1),
  .CLKOUT0_DIVIDE_F     (32),
  .CLKOUT0_PHASE        (0.000),
  .CLKIN1_PERIOD        (10.000)
) mmcme2_clk_tx_inst (
  .CLKIN1              (clk_100_i),
  .RST                 (1'b0),
  .PWRDWN              (1'b0),

  .CLKOUT0             (ref_clk),

  .CLKFBOUT            (clkfbout),
  .CLKFBIN             (clkfbin),

  .LOCKED              (locked)
);

BUFGCE clk_net_buf (
  .CE (locked),
  .I  (ref_clk),
  .O  (eth_ref_clk)
);

wire       tx_vld;
wire [3:0] tx_dat;
wire       tx_ack;
wire       tx_eof;

//The Ethernet TX MAC, which is responsible for prepending the preamble and
//appending the CRC
tx_mac tx_mac_inst (

    .clk_tx(eth_tx_clk_i),

    .tx_vld(tx_vld),
    .tx_eof(tx_eof),
    .tx_dat(tx_dat),
    .tx_ack(tx_ack),

    .mii_tx_en(eth_tx_en),
    .mii_tx_dat(eth_txd)
);

(* dont_touch = "true" *)(* mark_debug = "true" *) wire       rx_vld;
(* dont_touch = "true" *)(* mark_debug = "true" *) wire [3:0] rx_dat;
(* dont_touch = "true" *)(* mark_debug = "true" *) wire       rx_eof;

//The Ethernet RX MAC, which is responsible for stripping the preamble and CRC
rx_mac rx_mac_inst (

    .clk_rx(eth_rx_clk_i),

    .rx_vld(rx_vld),
    .rx_eof(rx_eof),
    .rx_dat(rx_dat),

    .mii_rx_dv(eth_rx_dv),
    .mii_rxd(eth_rxd)
);

//Output the rx counts on the VIOs
reg [31:0] rx_cnt = 0;
always @(posedge eth_rx_clk_i)
    if (rx_vld && rx_eof)
        rx_cnt <= rx_cnt + 1;

assign probe_in0 = rx_cnt;

//////////////////////////////////////////////////////////////////
//Ethernet packet loopback
//////////////////////////////////////////////////////////////////

xpm_fifo_async#(
    .FIFO_MEMORY_TYPE("auto"), //String
    .FIFO_READ_LATENCY(0),     //DECIMAL
    .FIFO_WRITE_DEPTH(64),     //DECIMAL
    .READ_DATA_WIDTH(5),       //DECIMAL
    .READ_MODE("fwft"),        //String
    .USE_ADV_FEATURES("1000"), //String
    .WRITE_DATA_WIDTH(5)       //DECIMAL
) xpm_fifo_async_inst (

    .wr_clk(eth_rx_clk_i),
    .rd_clk(eth_tx_clk_i),

    .rst(1'b0),

    .full(),
    .wr_en(rx_vld),
    .din({rx_eof, rx_dat}),

    .data_valid(tx_vld),
    .rd_en(tx_ack),
    .dout({tx_eof, tx_dat})
);

endmodule

