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
    output [3:0] eth_txd,

    //DDR
    inout  [15:0] ddr3_dq,
    inout  [1:0]  ddr3_dqs_n,
    inout  [1:0]  ddr3_dqs_p,
    output [13:0] ddr3_addr,
    output [2:0]  ddr3_ba,
    output        ddr3_ras_n,
    output        ddr3_cas_n,
    output        ddr3_we_n,
    output        ddr3_reset_n,
    output [0:0]  ddr3_ck_p,
    output [0:0]  ddr3_ck_n,
    output [0:0]  ddr3_cke,
    output [0:0]  ddr3_cs_n,
    output [1:0]  ddr3_dm,
    output [0:0]  ddr3_odt

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

(* keep = "true" *) wire eth_rx_clk_i;
(* keep = "true" *) wire eth_tx_clk_i;

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

wire [63:0] probe_in0;
wire [63:0] probe_in1;
wire [63:0] probe_in2;
wire [63:0] probe_in3;
wire [63:0] probe_out0;
wire [63:0] probe_out1;
wire [63:0] probe_out2;
wire [63:0] probe_out3;

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

wire ddr_ref, ddr_ref_i;

//Generate the reference clock needed by the external Ethernet phy
MMCME2_BASE #(
  .CLKFBOUT_MULT_F      (8),
  .DIVCLK_DIVIDE        (1),
  .CLKOUT0_DIVIDE_F     (32),
  .CLKOUT0_PHASE        (0.000),
  .CLKOUT1_DIVIDE       (4),
  .CLKOUT1_PHASE        (0.000),
  .CLKIN1_PERIOD        (10.000)
) mmcme2_clk_tx_inst (
  .CLKIN1              (clk_100_i),
  .RST                 (1'b0),
  .PWRDWN              (1'b0),

  .CLKOUT0             (ref_clk),
  .CLKOUT1             (ddr_ref_i),

  .CLKFBOUT            (clkfbout),
  .CLKFBIN             (clkfbin),

  .LOCKED              (locked)
);

BUFGCE clk_net_buf (
  .CE (locked),
  .I  (ref_clk),
  .O  (eth_ref_clk)
);

BUFGCE clk_ddr_buf (
  .CE (locked),
  .I  (ddr_ref_i),
  .O  (ddr_ref)
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

//Chunk up the packet
reg [119:0] buffered_rx = 0;
reg [4:0]   rx_buf_cnt  = 0;
reg         do_write    = 0;
reg [3:0]   bytes_valid = 0;
reg         last_eof    = 0;

always @(posedge eth_rx_clk_i) begin
    if (rx_vld) begin
        if (rx_eof || rx_buf_cnt == 29)
            rx_buf_cnt <= 0;
        else
            rx_buf_cnt <= rx_buf_cnt + 1;
        buffered_rx[4*rx_buf_cnt +: 4] <= rx_dat;
    end
    do_write    <= rx_vld && (rx_eof || rx_buf_cnt == 29);
    bytes_valid <= rx_buf_cnt[4:1];
    last_eof    <= rx_vld && rx_eof;
end

wire         tx_chunk_valid;
wire         tx_chunk_ack;
wire         tx_chunk_eof;
wire [3:0]   tx_chunk_size;
wire [119:0] tx_chunk;

wire [124:0] data_dram_in;
wire         vld_dram_in;
wire         ack_dram_in;
wire [124:0] data_dram_out;
wire         vld_dram_out;
wire         full_dram_out;

wire        ui_clk;

//CDC FIFO from Ethernet RX clock to DDR UI clock
xpm_fifo_async#(
    .FIFO_MEMORY_TYPE("auto"), //String
    .FIFO_READ_LATENCY(0),     //DECIMAL
    .FIFO_WRITE_DEPTH(256),    //DECIMAL
    .READ_DATA_WIDTH(125),     //DECIMAL
    .READ_MODE("fwft"),        //String
    .USE_ADV_FEATURES("1000"), //String
    .WRITE_DATA_WIDTH(125)     //DECIMAL
) xpm_fifo_async_rx_inst (

    .wr_clk(eth_rx_clk_i),
    .rd_clk(ui_clk),

    .rst(1'b0),

    .full(),
    .wr_en(do_write),
    .din({last_eof, bytes_valid, buffered_rx}),

    .data_valid(vld_dram_in),
    .rd_en(ack_dram_in),
    .dout(data_dram_in)
);

//CDC FIFO from DDR UI clock to Ethernet TX domain
xpm_fifo_async#(
    .FIFO_MEMORY_TYPE("auto"), //String
    .FIFO_READ_LATENCY(0),     //DECIMAL
    .FIFO_WRITE_DEPTH(256),    //DECIMAL
    .READ_DATA_WIDTH(125),     //DECIMAL
    .READ_MODE("fwft"),        //String
    .USE_ADV_FEATURES("1000"), //String
    .WRITE_DATA_WIDTH(125)     //DECIMAL
) xpm_fifo_async_tx_inst (

    .wr_clk(ui_clk),
    .rd_clk(eth_tx_clk_i),

    .rst(1'b0),

    .full(full_dram_out),
    .wr_en(vld_dram_out),
    .din(data_dram_out),

    .data_valid(tx_chunk_valid),
    .rd_en(tx_chunk_ack),
    .dout({tx_chunk_eof, tx_chunk_size, tx_chunk})
);

//Unchunk the packet
reg [4:0] tx_cnt = 0;
assign tx_dat       = tx_chunk[4*tx_cnt +: 4];
assign tx_vld       = tx_chunk_valid;
assign tx_eof       = tx_chunk_eof && tx_cnt == {tx_chunk_size, 1'b1};
assign tx_chunk_ack = tx_ack && (tx_eof || tx_cnt == 29);

always @(posedge eth_tx_clk_i) begin
    if (tx_chunk_valid && tx_ack)
        if (tx_chunk_ack)
            tx_cnt <= 0;
        else
            tx_cnt <= tx_cnt + 1;
end

//////////////////////////////////////////////////////////////////
//DDR packet FIFO
//////////////////////////////////////////////////////////////////

wire         ui_clk_sync_rst;
wire         init_calib_complete;
wire [11:0]  device_temp;

wire [127:0] app_rd_data;
wire         app_rd_data_end;
wire         app_rd_data_valid;
wire         app_rdy;
wire         app_wdf_rdy;
wire         app_sr_active;
wire         app_ref_ack;
wire         app_zq_ack;

wire [2:0]   app_cmd;
wire         app_en;
wire [23:0]  app_addr;
wire [127:0] app_wdf_data;

//FIFO logic
reg  [23:0]  read_ptr  = 0;
reg  [23:0]  write_ptr = 0;

wire empty = read_ptr == write_ptr;
wire full  = read_ptr == write_ptr + 1;

wire req_fifo_write = !full  && vld_dram_in;
wire req_fifo_read  = !empty && !full_dram_out;

always @(posedge ui_clk)
    if (req_fifo_write && ack_dram_in)
        write_ptr <= write_ptr + 1;

always @(posedge ui_clk)
    if (req_fifo_read && vld_dram_out)
        read_ptr <= read_ptr + 1;

reg        state   = 0;
localparam IDLE    = 0;
localparam READING = 1;

always @(posedge ui_clk)
    case (state)
        IDLE: 
            if (app_rdy)
                if (req_fifo_read)
                    state <= READING;
        READING:
            if (app_rd_data_valid)
                state <= IDLE;
    endcase

assign ack_dram_in   = state == IDLE && app_rdy && app_wdf_rdy && !req_fifo_read;
assign app_en        = state == IDLE && (req_fifo_read || req_fifo_write);
wire   write_en      = state == IDLE && req_fifo_write && app_rdy && !req_fifo_read;
assign app_cmd       = write_en ? 3'b0      : 3'b1;
assign app_addr      = write_en ? write_ptr : read_ptr;
assign app_wdf_data  = data_dram_in;
assign data_dram_out = app_rd_data;
assign vld_dram_out  = state == READING && app_rd_data_valid;

mig_7series_0 mig_7series_0_inst (
    // Inouts
    .ddr3_dq             (ddr3_dq),     
    .ddr3_dqs_n          (ddr3_dqs_n),
    .ddr3_dqs_p          (ddr3_dqs_p),

    // Outputs
    .ddr3_addr           (ddr3_addr),
    .ddr3_ba             (ddr3_ba),
    .ddr3_ras_n          (ddr3_ras_n),
    .ddr3_cas_n          (ddr3_cas_n),
    .ddr3_we_n           (ddr3_we_n),
    .ddr3_reset_n        (ddr3_reset_n),
    .ddr3_ck_p           (ddr3_ck_p),
    .ddr3_ck_n           (ddr3_ck_n),
    .ddr3_cke            (ddr3_cke),
    .ddr3_cs_n           (ddr3_cs_n),
    .ddr3_dm             (ddr3_dm),
    .ddr3_odt            (ddr3_odt),

    // Clocks
    .sys_clk_i           (clk_100_i),
    .clk_ref_i           (ddr_ref),

    // User interface signals
    .app_addr            ({app_addr, 4'b0}),   //input [27:0]       
    .app_cmd             (app_cmd),            //input [2:0]        
    .app_en              (app_en),             //input              
    .app_wdf_data        (app_wdf_data),       //input [127:0]      
    .app_wdf_end         (write_en),           //input              
    .app_wdf_mask        (0),                  //input [15:0]       
    .app_wdf_wren        (write_en),           //input              
    .app_rd_data         (app_rd_data),        //output [127:0]     
    .app_rd_data_end     (app_rd_data_end),    //output             
    .app_rd_data_valid   (app_rd_data_valid),  //output             
    .app_rdy             (app_rdy),            //output             
    .app_wdf_rdy         (app_wdf_rdy),        //output             
    .app_sr_req          (0),                  //input              
    .app_ref_req         (0),                  //input              
    .app_zq_req          (0),                  //input              
    .app_sr_active       (app_sr_active),      //output             
    .app_ref_ack         (app_ref_ack),        //output             
    .app_zq_ack          (app_zq_ack),         //output             

    .ui_clk              (ui_clk),
    .ui_clk_sync_rst     (ui_clk_sync_rst),
    .init_calib_complete (init_calib_complete),
    .device_temp         (device_temp),

    .sys_rst             (1'b1)
  );

endmodule

