`timescale 1ns / 1ps

module text_renderer 
#(
	parameter W = 240,
	parameter H = 240,
	parameter COLOR_FG = 16'hFFFF,
	parameter COLOR_BG = 16'h0000
)(
	input                         clk,    
	input                         rst_n,  
	
	input                         start_draw,
                      
	input [7:0]                   bcd3, // thousands 
	input [7:0]                   bcd2, // hundreds
	input [7:0]                   bcd1, // tens
	input [7:0]                   bcd0, // decimal

	output reg done,

	// interface for writing in fb_bram
    output reg                    we,
    output reg [15:0]             din,
    output reg [$clog2(W*H)-1:0]  waddr

);

localparam START_X = 30;
localparam START_Y = 110;
// FM 100.3 MHz
localparam NUM_CHARS = 12;

reg [3:0] l_bcd3, l_bcd2, l_bcd1, l_bcd0;

reg [3:0] char_idx;
reg [3:0] row_idx;
reg [2:0] col_idx;

reg [7:0] current_char;

always @(*) begin
	case (char_idx)
		0: current_char = 8'd70; // F
		1: current_char = 8'd77; // M
		2: current_char = 8'd32; // space
		3: current_char = (l_bcd3 ? (l_bcd3 + 8'd48) : 8'd32); // hundreds
		4: current_char = 8'd48 + l_bcd2; // tens
		5: current_char = 8'd48 + l_bcd1; // ones
		6: current_char = 8'd46; // .
		7: current_char = 8'd48 + l_bcd0; // decimal
		8: current_char = 8'd32; // space
		9: current_char = 8'd77; // M
		10: current_char = 8'd72; // H
		11: current_char = 8'd122; // z
		default: current_char = 8'd32;
	endcase
end

wire [11:0] font_addr = {current_char, row_idx};
wire [7:0]  font_data;

font_rom i_font_rom (
	.clk(clk),
	.addr(font_addr),
	.data(font_data)
);

// FSM
localparam IDLE = 0, CLEAR_BG = 1, WAIT_ROM = 2, DRAW = 3;
reg [1:0] state;

reg [15:0] clear_addr;

always @(posedge clk) begin
	if (!rst_n) begin
		state <= IDLE;
		we <= 0;
		done <= 0;
	end else begin
		case (state)
			IDLE: begin
				we <= 0;
				done <= 0;
				if (start_draw) begin
					l_bcd3 <= bcd3;
					l_bcd2 <= bcd2;
					l_bcd1 <= bcd1;
					l_bcd0 <= bcd0;
					
					char_idx <= 0;
					row_idx  <= 0;
					col_idx  <= 0;
					state <= CLEAR_BG;
				end
			end
			
			CLEAR_BG: begin
				we <= 1;
				waddr <= clear_addr;
				din <= COLOR_BG;

				if (clear_addr >= (W*H)-1) begin
				    clear_addr <= 0;
					state <= WAIT_ROM;					
				end else begin
					clear_addr <= clear_addr + 1'b1;
				end

			end

			WAIT_ROM: begin
				we <= 0;
				state <= DRAW;
			end

			DRAW: begin
				we <= 1;
				waddr <= ( ((row_idx+START_Y)*W) + (START_X + (char_idx)*8) + (7-col_idx) );
				din <= font_data[col_idx] ? COLOR_FG : COLOR_BG;

				if (col_idx == 7) begin
					col_idx <= 0;
					if (row_idx == 15) begin
						row_idx <= 0;
						if (char_idx == NUM_CHARS - 1) begin
							state <= IDLE;
							done <= 1;
							we <= 0;
						end else begin
							char_idx <= char_idx + 1;
							state <= WAIT_ROM;
						end
					end else begin
						row_idx <= row_idx + 1;
						state <= WAIT_ROM;
					end
				end else begin
					col_idx <= col_idx + 1;
				end

			end

		endcase
	end
end

endmodule 