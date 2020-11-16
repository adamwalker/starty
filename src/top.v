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

endmodule

