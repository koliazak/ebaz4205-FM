`timescale 1ns / 1ps

module tea5767_freq_pll_converter (
    input  wire        clk,
    
    
    input  wire [10:0] freq_in,  // Example: 1005 (100.5 MHz)
    output reg  [13:0] pll_out,
    


    input  wire [13:0] pll_in,   
    output reg  [10:0] freq_out
);


    reg [31:0] tx_numerator;
    reg [27:0] rx_freq_hz;
    reg [43:0] rx_multiplier;

    always @(posedge clk) begin

		// PLL = (freq100khz*100000 + 225000) / 8192
        tx_numerator <= (freq_in * 32'd100000) + 32'd225000;
        pll_out <= (tx_numerator >> 13);

        // F(hz) = PLL*8192 - 225000
        // F(100kHz) = F(hz) / 100000
        // Division is expensive, but /100000 is the same as *1/100000
        // 1/100000 is approximately 42950/4294967296
        // So we can just multiply by 42950 and shift 32 bits right

        rx_freq_hz <= (pll_in * 28'd8192) - 28'd225000;
        rx_multiplier <= rx_freq_hz * 44'd42950;
        freq_out <= (rx_multiplier >> 32);
    end

endmodule