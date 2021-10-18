module top (
    //System clock
    input        clk_100,

    //GPIO
    input  [3:0] sw,
    input  [3:0] btn,

    output [3:0] led_b,
    output [3:0] led_g,
    output [3:0] led_r,

    output [3:0] led

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

wire clkfbin;
wire clkfbout;
wire locked;
wire ref_clk;
wire clk;

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
  .O  (clk)
);

endmodule

