`timescale 1ns / 1ps

module tea5767_controller (
    input  wire clk,
    input  wire rst_n,

    // Control (Pulses)

    input  wire start,
    input  wire abort,
    input  wire clr_done,


    // Configuration
    input  wire [10:0]    freq_khz, // 100.5 MHz -> 1005 | 99.0 MHz -> 990
    input  wire           search_en,
    input  wire           search_up,
    input  wire           mono,
    input  wire           mute,
    input  wire           standby,

    // Status
    output  wire          busy,
    output  reg           done,
    output  wire          station_found,
    output  wire          stereo,
    output  wire          scanning,
    output  wire          tuned,


    // Result
    output  wire [10:0]   scan_result_khz,
    output  wire          scan_result_stereo,
    output  wire          missed_ack,
    output  wire          i2c_error,


    // I2C Pins
    input  wire scl_i,
    output wire scl_o,
    output wire scl_t,
    input  wire sda_i,
    output wire sda_o,
    output wire sda_t
    
);

    localparam [6:0] TEA5767_ADDR = 7'h60;


    // prescale = Fclk / (FI2Cclk * 4) 
    // prescale = 50_000_000 / (100_000 * 4) = 125
    localparam [15:0] I2C_PRESCALE = 16'd125; 
    localparam COUNTER_10MS_50MHZ = 500000;
    reg [18:0] counter;

    reg  [6:0] cmd_address;
    reg        cmd_start;
    reg        cmd_read;
    reg        cmd_write;
    reg        cmd_write_multiple;
    reg        cmd_stop;
    reg        cmd_valid;
    wire       cmd_ready;

    reg  [7:0] data_tdata;
    reg        data_tvalid;
    reg        data_tlast;
    wire       data_tready;

    (* mark_debug = "true" *) wire       m_axis_data_tvalid;
    (* mark_debug = "true" *) wire [7:0] m_axis_data_tdata;
    (* mark_debug = "true" *) wire       m_axis_data_tlast;
    (* mark_debug = "true" *) reg        m_axis_data_tready;

    i2c_master i2c_inst (
        .clk(clk),
        .rst(~rst_n),
        
        .s_axis_cmd_address(cmd_address),
        .s_axis_cmd_start(cmd_start),
        .s_axis_cmd_read(cmd_read),
        .s_axis_cmd_write(cmd_write),
        .s_axis_cmd_write_multiple(cmd_write_multiple),
        .s_axis_cmd_stop(cmd_stop),
        .s_axis_cmd_valid(cmd_valid),
        .s_axis_cmd_ready(cmd_ready),

        .s_axis_data_tdata(data_tdata),
        .s_axis_data_tvalid(data_tvalid),
        .s_axis_data_tready(data_tready),
        .s_axis_data_tlast(data_tlast),

        .m_axis_data_tdata(m_axis_data_tdata),
        .m_axis_data_tvalid(m_axis_data_tvalid),
        .m_axis_data_tready(m_axis_data_tready),
        .m_axis_data_tlast(m_axis_data_tlast),

        .scl_i(scl_i),
        .scl_o(scl_o),
        .scl_t(scl_t),
        .sda_i(sda_i),
        .sda_o(sda_o),
        .sda_t(sda_t),

        .busy(busy),
        .bus_control(),
        .bus_active(),
        .missed_ack(missed_ack_out),

        .prescale(I2C_PRESCALE),
        .stop_on_idle(1'b0)
    );

    localparam basic_config_b0 = 8'b10101111;
    localparam basic_config_b1 = 8'b11101111;
    localparam basic_config_b2 = 8'b00010000;
    localparam basic_config_b3 = 8'b00010110;
    localparam basic_config_b4 = 8'h00;

    reg[7:0] config_b0, config_b1, config_b2, config_b3, config_b4;   
    (* mark_debug = "true" *) reg[7:0] status_b0, status_b1, status_b2, status_b3, status_b4;   

    always @(posedge clk) begin
        if (!rst_n) begin
            config_b0 <= basic_config_b0;
            config_b1 <= basic_config_b1;
            config_b2 <= basic_config_b2;
            config_b3 <= basic_config_b3;
            config_b4 <= basic_config_b4;
        end else begin
            config_b0 <= {mute, search_en, pll_word[13:8]};
            config_b1 <= pll_word[7:0];
            config_b2 <= {search_up, 2'b10, 1'b1, mono, 3'b000};
            config_b3 <= {1'b0, standby, 6'b010001};
            config_b4 <= 8'h00;
        end
    end

    wire [13:0] pll_word;
    tea5767_freq_pll_converter i_pll_word_gen (
        .clk           (clk),
        .freq_in       (freq_khz),
        .pll_out       (pll_word),

        .pll_in        ({status_b0[5:0], status_b1}),
        .freq_out      (scan_result_khz)
        );

    // State Machine
    localparam STATE_IDLE         = 4'd0;
    localparam STATE_SEND_CMD     = 4'd1;
    localparam STATE_SEND_DATA    = 4'd2;
    localparam STATE_INIT_READ    = 4'd3;
    localparam STATE_READ_CMD     = 4'd4;
    localparam STATE_READ_WAIT    = 4'd5;
    localparam STATE_CHECK_SEARCH = 4'd6;
    localparam STATE_WAIT_10MS    = 4'd7;
    localparam STATE_DONE         = 4'd8;

    reg [3:0] state = STATE_IDLE;
    reg [2:0] byte_cnt = 3'd0;

    always @(posedge clk) begin
        if (!rst_n || abort) begin
            counter <= 0;
            state <= STATE_IDLE;
            cmd_valid <= 1'b0;
            data_tvalid <= 1'b0;
            byte_cnt <= 3'd0;
            done <= 1'b0;
        end else begin
            
            if (clr_done) begin
                done <= 0;
            end
            case (state)
                STATE_IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                        cmd_address <= TEA5767_ADDR;
                        cmd_start <= 1'b0;
                        cmd_read <= 1'b0;
                        cmd_write <= 1'b0;
                        cmd_write_multiple <= 1'b1;
                        cmd_stop <= 1'b1;
                        cmd_valid <= 1'b1;
                     
                        byte_cnt <= 3'd0;
                        state <= STATE_SEND_CMD;
                    end
                end

                STATE_SEND_CMD: begin
                    if (cmd_ready && cmd_valid) begin
                        cmd_valid <= 1'b0;
                        state <= STATE_SEND_DATA;
                    end
                end

                STATE_SEND_DATA: begin
                    data_tvalid <= 1'b1;
                    
                    case (byte_cnt)
                        3'd0: data_tdata <= config_b0;
                        3'd1: data_tdata <= config_b1;
                        3'd2: data_tdata <= config_b2;
                        3'd3: data_tdata <= config_b3;
                        3'd4: data_tdata <= config_b4;
                        default: data_tdata <= 8'h00;
                    endcase

                    data_tlast <= (byte_cnt == 3'd4) ? 1'b1 : 1'b0;

        
                    if (data_tready && data_tvalid) begin
                        if (byte_cnt == 3'd4) begin
                            data_tvalid <= 1'b0;
                            data_tlast <= 1'b0;
                            state <= STATE_INIT_READ;
                        end else begin                    
                            byte_cnt <= byte_cnt + 1;
                        end
                    end
                end

                STATE_INIT_READ: begin 
                    cmd_address         <= TEA5767_ADDR;
                    cmd_start           <= 1'b0;
                    cmd_read            <= 1'b1;
                    cmd_write           <= 1'b0;
                    cmd_write_multiple  <= 1'b0;
                    cmd_stop            <= 1'b0;
                    cmd_valid           <= 1'b1;
                    byte_cnt            <= 3'd0;
                    state               <= STATE_READ_CMD;
                end

                STATE_READ_CMD: begin
                    if (cmd_ready && cmd_valid) begin
                        cmd_valid <= 1'b0;
                        m_axis_data_tready <= 1'b1;
                        state <= STATE_READ_WAIT;
                    end 
                end

                STATE_READ_WAIT: begin
                    if (m_axis_data_tvalid) begin
                     m_axis_data_tready <= 1'b0;
 
                        case (byte_cnt)
                            3'd0: status_b0 <= m_axis_data_tdata;
                            3'd1: status_b1 <= m_axis_data_tdata;
                            3'd2: status_b2 <= m_axis_data_tdata;
                            3'd3: status_b3 <= m_axis_data_tdata;
                            3'd4: status_b4 <= m_axis_data_tdata;
                        endcase
                                             
                        if (byte_cnt == 3'd4) begin
                            state <= STATE_CHECK_SEARCH;
                        end else begin
                            byte_cnt <= byte_cnt + 1'b1;

                            if (byte_cnt == 3'd3) begin
                                cmd_stop <= 1'b1;
                            end
                            cmd_valid <= 1'b1;
                            state <= STATE_READ_CMD;
                        end
                    end
                end

                STATE_CHECK_SEARCH: begin
                    if (search_en && !status_b0[7]) begin
                        state <= STATE_WAIT_10MS;
                    end else begin                            
                        state <= STATE_DONE;
                    end
                end

                STATE_WAIT_10MS: begin
                    if (counter >= COUNTER_10MS_50MHZ) begin
                        state <= STATE_INIT_READ;
                        counter <= 0;
                    end else begin
                        counter <= counter + 1'b1;
                        state <= STATE_WAIT_10MS;
                    end
                end

                STATE_DONE: begin
                    if (!busy) begin
                        done  <= 1'b1;
                        state <= STATE_IDLE;
                    end
                end
            endcase
        end
    end
    
    assign station_found      = status_b0[7] & ~status_b0[6];
    assign scanning           = ~status_b0[7];                
    assign tuned              = status_b0[7];                 
    assign stereo             = status_b2[7];                 
    assign scan_result_stereo = status_b2[7];
    
endmodule