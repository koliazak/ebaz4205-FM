`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/24/2025 12:18:24 PM
// Design Name: 
// Module Name: debounce
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module debounce 
    #(
    parameter CLK_FREQ_HZ = 50000000,
    parameter DEBOUNCE_MS = 10
    )
    (
    input btn_in,
    input clk,
    output reg btn_out
    
    );
    
    // CLK_FREQ_HZ * (debounce_ms / 1_000)
    localparam COUNT_MAX = CLK_FREQ_HZ * DEBOUNCE_MS / 1000;
    localparam COUNTER_BITS = $clog2(COUNT_MAX);
    
    reg[COUNTER_BITS-1:0] counter = 0;
    reg btn_sync_0;
    reg btn_sync;
    reg btn_stable = 0;
    
    
    always @(posedge clk) begin
        btn_sync_0 <= btn_in;
        btn_sync <= btn_sync_0;
    end
    
    always @(posedge clk) begin
        if (btn_sync != btn_stable) begin
            if (counter == COUNT_MAX-1) begin
                btn_stable <= btn_sync;
                counter <= 0;
            end else begin
                counter <= counter + 1;                
            end
         end else begin
            counter <= 0;
         end
         
         btn_out <= btn_stable;
     end           
        
endmodule
