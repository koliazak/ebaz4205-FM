`timescale 1ns / 1ps

module i2s_rx_master (
    input  wire        mclk,      // 2.048 MHz
    input  wire        rst_n,
    

    output wire        i2s_mclk,  // System clock (MCLK)
    output wire        i2s_bclk,  // Bit clock (BCLK)
    output wire        i2s_lrck,  // Left/Right clock (LRCK)
    input  wire        i2s_din,   // Data in (DOUT from ADC)

    output reg [23:0]  left_data,
    output reg [23:0]  right_data,
    output reg         data_valid
);

    assign i2s_mclk = mclk;


    reg [7:0] master_div;

    always @(posedge mclk or negedge rst_n) begin
        if (!rst_n) begin
            master_div <= 0;
        end else begin
            master_div <= master_div + 1;
        end
    end

    assign i2s_bclk = master_div[1]; // 512 kHz
    assign i2s_lrck = master_div[7]; // 8 kHz

    // We need to have 64 BCLK per sample. 8kHz * 64 = 512kHz
    // 2048kHz (mclk) / 512kHz = 4. So BCLK has to be 4 times slower than mclk.
    // master_div[1] two ticks is 0, two ticks is 1. So we recieve our signal.
    // 
    // We need 1 LRCK per sample. As our sampling frequency is 8kHz we need 8kHz LRCK frequency
    // 2048kHz (mclk) / 8kHz = 256
    // master_div[7] 128 ticks is 0, 128 ticks is 1. This is how we get needed frequency



    // I2S Reciever
    wire         bclk_rising = (master_div[1:0] == 2'b01);
    wire [4:0]   bit_idx     =  master_div[6:2];
    wire         is_right_ch =  master_div[7];
    reg  [23:0]  shift_reg;
    
    always @(posedge mclk or negedge rst_n) begin
        if (!rst_n) begin 
            shift_reg  <= 0;
            left_data  <= 0;
            right_data <= 0;
            data_valid <= 0;
        end else begin
            data_valid <= 0;
            
            if (bclk_rising) begin
                if (bit_idx == 5'b0) begin
                    shift_reg <= 0;
                end else if (bit_idx >= 5'b1 && bit_idx <= 5'd24) begin
                    shift_reg <= {shift_reg[22:0], i2s_din};
                end else if (bit_idx == 5'd31) begin
                    if (!is_right_ch) begin
                        left_data <= shift_reg;
                    end else begin
                        right_data <= shift_reg;
                        data_valid <= 1;
                    end
                end
            end

        end
    end

endmodule