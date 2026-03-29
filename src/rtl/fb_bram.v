`timescale 1ns / 1ps

module fb_bram
    #(
    parameter W = 240, H = 240
    )
    (
    input clkw,
    input clkr,
    
    input we,
    input[15:0] din,
    input [$clog2(W*H)-1:0] waddr,
    
    input [$clog2(W*H)-1:0] raddr,
    output reg [15:0] dout
    );
    
    localparam DEPTH = W*H;
    (* ram_style = "block" *) reg [15:0] mem[0:DEPTH-1];
    
    always @(posedge clkr) begin
        dout <= mem[raddr];
    end
    
    always @(posedge clkw) begin
        if (we) begin
            mem[waddr] <= din;
        end
    end
    
endmodule