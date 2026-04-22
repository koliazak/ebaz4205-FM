`timescale 1ns / 1ps

module lcd_driver
    #(
    parameter W=240,
    parameter H=240,
    parameter FREQ_CLK = 50_000_000
    )
    (
    input clk,
    input rst,
	
    input valid,
    output reg ready = 0,
	
    output DC,   // data strobe: command or data. "0" - cmd, "1" - data
    output SCL,  // clk SPI
    output SDA,  // data SPI
    output reg nRES = 1,  // reset LCD. "0" - reset, "1" - normal work

    input [15:0] fb_dout,
    output reg [$clog2(W*H)-1:0] fb_raddr

    );

reg [7:0] state_lcd = 0;
reg done_init = 0;  

reg [31:0] delay_cnt = 0; 
reg [3:0] ch_reg = 0;

reg send_valid = 0;    
reg send_cd = 0;
reg [7:0] send_data = 0;
wire send_ready;

reg [7:0] SLPOUT [0:0];
reg [7:0] COLMOD [0:1];
reg [7:0] MADCTL [0:1];
reg [7:0] START_WORK [0:2];
reg [7:0] CASET [0:4];
reg [7:0] RASET [0:4];
reg [7:0] RAMWR [0:2];


reg [$clog2(W*H)-1:0] idx = 0;
reg [15:0] pixel;

initial begin
    //Sleep mode out
	SLPOUT[0] = 'h11;

	//RGB format 
	COLMOD[0] = 'h3A; //Interface pixel format(RGB): 5:6:5
	COLMOD[1] = 'h55; 

	// cmd and params MADCTL
	MADCTL[0] = 'h36; //Mem access ctrl (directions): Row/col addr, bottom-top refresh, RGB order
	MADCTL[1] = 'h00;

	// cmd to work.
	START_WORK[0] = 'h21; // INVON, turns on inversion
	START_WORK[1] = 'h13; // NORON, normal display mode on
	START_WORK[2] = 'h29; // DISPON, display on
	
	//CASET
	// CASET = ['h2A, 'h00, 'h00, 'h00, W-1];
	CASET[0] = 'h2A;
	CASET[1] = 'h00; //H // X1 == 0
	CASET[2] = 'h00; //L
	CASET[3] = 'h00; //H // X2 == 239
	CASET[4] = 'hEF; //L = 239 = 0xEF

	//RASET
	// RASET = ['h2B, 'h00, 'h00, 'h00, H-1];
	RASET[0] = 'h2B;
	RASET[1] = 'h00;
	RASET[2] = 'h00;
	RASET[3] = 'h00;
	RASET[4] = 'hEF; // H = 239 = 0xEF
	
	//RAMWR
	RAMWR[0] = 'h2C;
	RAMWR[1] = 'h00;
	RAMWR[2] = 'h00;
end

always @(posedge clk)
begin
    if (!rst) begin
        state_lcd <= 'd0;
		delay_cnt <= 'd0;
		ch_reg <= 'd0;
		
		done_init <= 'd0;
		ready <= 'd0;
		idx <= 'd0;
		fb_raddr <= 'd0;
    end else begin
		if (!done_init) begin
			case (state_lcd)
				0: begin // reset off
					nRES <= 'd1;
					if (delay_cnt >= (FREQ_CLK)) begin
						delay_cnt <= 'd0;
						state_lcd <= 1;
					end else delay_cnt <= delay_cnt + 1;
				end
				1: begin // reset on      
					nRES <= 'd0;
					if (delay_cnt >= (FREQ_CLK)) begin
						delay_cnt <= 'd0;
						state_lcd <= 2;
					end else delay_cnt <= delay_cnt + 1;
				end
				2: begin // reset off      
					nRES <= 'd1;
					if (delay_cnt >= (2*FREQ_CLK)) begin
						delay_cnt <= 'd0;
						state_lcd <= 3;
					end else delay_cnt <= delay_cnt + 1;
				end
				3: begin //send cmd SLPOUT ('h11); see datasheet page 181.
					send_cd <= (ch_reg == 'd0) ? 'd0 : 'd1;
					if (send_ready & (!send_valid)) begin
						send_data <= SLPOUT[ch_reg];
						send_valid <= 'd1;
						if (ch_reg == 0) begin
							state_lcd <= 4;
							ch_reg <= 'd0;
						end else ch_reg <= ch_reg + 1;
					end else begin
						send_valid <= 'd0;
					end  
				end
				4: begin //send cmd COLMOD ('h3A); see datasheet page 221.
					send_cd <= (ch_reg == 'd0) ? 'd0 : 'd1;
					if (send_ready & (!send_valid)) begin
						send_data <= COLMOD[ch_reg];
						send_valid <= 'd1;
						if (ch_reg == 1) begin
							state_lcd <= 5;
							ch_reg <= 'd0;
						end else ch_reg <= ch_reg + 1;
					end else begin
						send_valid <= 'd0;
					end  
				end
				5: begin //send cmd MADCTL ('h36); see datasheet page 212.
					send_cd <= (ch_reg == 'd0) ? 'd0 : 'd1;
					if (send_ready & (!send_valid)) begin
						send_data <= MADCTL[ch_reg];
						send_valid <= 'd1;
						if (ch_reg == 1) begin
							state_lcd <= 6;
							ch_reg <= 'd0;
						end else ch_reg <= ch_reg + 1;
					end else begin
						send_valid <= 'd0;
					end               
				end
				6: begin //send cmd INVON ('h21), NORON('h13), DISPON('h29). 0 bytes data; see datasheet page 187, 184, 193.
					send_cd <= 'd0; 
					if (send_ready & (!send_valid)) begin
						send_data <= START_WORK[ch_reg];
						send_valid <= 'd1;
						if (ch_reg == 2) begin
							state_lcd <= 7;
							ch_reg <= 'd0;
						end else ch_reg <= ch_reg + 1;
					end else begin
						send_valid <= 'd0;
					end  
				end
				7: begin //init done
					   send_valid <= 'd0;
					   if (send_ready & (!send_valid)) begin
						  state_lcd <= 0;
						  done_init <= 'd1;
						  ready <= 'd1;
					   end                                
				end                                                                                                        
			endcase
		end else begin
			case (state_lcd)
				0:begin
				    if (valid & ready) begin
				       ready <= 'd0;
				       ch_reg <= 'd0;
				       state_lcd <= 1;
				    end
				end    
				1:begin       
				    //send cmd CASET ('h2A), 4 bytes data; see datasheet page 195.
					send_cd <= (ch_reg == 'd0) ? 'd0 : 'd1;
					if (send_ready & (!send_valid)) begin
					   send_data <= CASET[ch_reg];
					   send_valid <= 'd1;
					   if (ch_reg == 4) begin
					       state_lcd <= 2;
						   ch_reg <= 'd0;
					   end else ch_reg <= ch_reg + 1;
				    end else begin
					   send_valid <= 'd0;
					end
				end
				2: begin //send cmd RASET ('h2B), 4 bytes data; see datasheet page 197.
					send_cd <= (ch_reg == 'd0) ? 'd0 : 'd1;
					if (send_ready & (!send_valid)) begin
						send_data <= RASET[ch_reg];
						send_valid <= 'd1;
						if (ch_reg == 4) begin
							state_lcd <= 3;
							ch_reg <= 'd0;
						end else ch_reg <= ch_reg + 1;
					end else begin
						send_valid <= 'd0;
					end               
				end  
				3: begin //send cmd RAMWR ('h2C). see datasheet page 199. for set cursot position to (0,0)
					send_cd <= 'd0;
					if (send_ready & (!send_valid)) begin
						send_data <= RAMWR[0];
						send_valid <= 'd1;
						idx <= 0;
						state_lcd <= 4;
					end else begin
						send_valid <= 'd0;
					end               
				end
				4: begin // update idx, address
					fb_raddr <= idx;
					state_lcd <= 5;
				end
				5: begin
					pixel <= fb_dout;
					state_lcd <= 6;	
				end
				6: begin // send high
					if (send_ready & (!send_valid)) begin
						send_cd <= 'd1;
						send_data <= pixel[15:8];
						send_valid <= 1;
						state_lcd <= 7;
					end else begin
						send_valid <= 'd0;
					end
				end

				7: begin // send low
					if (send_ready & (!send_valid)) begin
						send_cd <= 'd1;
						send_data <= pixel[7:0];
						send_valid <= 1;

						if (idx >= W*H-1) begin
                            				ready <= 1;
							idx <= 0;
							state_lcd <= 0;				
						end else begin
							idx <= idx + 'd1;
							state_lcd <= 4;
						end
						
					end else begin
						send_valid <= 'd0;
					end
				end
			endcase   
		end
    end
end

send_byte send_byte_inst
(
    .clk		(clk),
    
    .valid 		(send_valid),
    .cmd_data 	(send_cd),
    .data  		(send_data),
    .ready 		(send_ready),
    
    .DC    		(DC),  
    .SCL   		(SCL), 
    .SDA   		(SDA) 
); 

endmodule

module send_byte
(
    input clk,
	
    input valid,
    input cmd_data, // cmd - '0', data - '1'
    input [7:0] data,
    output reg ready = 1,
    
    output reg DC = 0,  // data strobe: command or data. "0" - cmd, "1" - data
    output reg SCL = 1, // clk SPI
    output reg SDA = 0  // data SPI
);
        
reg [7:0] buf_data_send = 0;   
reg [2:0] state = 0;
reg [3:0] cnt_bits = 0;
     
always @(posedge clk)
begin
    case (state)
        0: begin // wait byte to send
            if (valid & ready) begin
                buf_data_send <= data;
                DC <= cmd_data;
                ready <= 'd0;
                state <= 'd1;            
            end else begin
                ready <= 'd1;
            end        
        end
        1: begin // send byte
            if (SCL == 1) begin //set SCL=0, need set data to SDA
                SDA <= buf_data_send[7];
                buf_data_send <= {buf_data_send,1'b0};
                SCL <= 'd0;
            end else begin
                SCL <= 'd1;
                if (cnt_bits == 'd7) begin
                    state <= 'd0;
                    cnt_bits <= 'd0;
                end else cnt_bits <= cnt_bits + 1;
            end
        end
    endcase    
end    
    
endmodule
