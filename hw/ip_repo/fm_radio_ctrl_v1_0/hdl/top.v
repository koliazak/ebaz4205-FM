`timescale 1ns / 1ps

module top (
    input  wire clk,
    input  wire rst_n,     
    
    // Physical buttons
    input  wire start,
    input  wire search_en_btn,
    
    // AXI Control inputs
    input  wire sw_ctrl_start,
    input  wire sw_ctrl_clr_done,
    input  wire [10:0] sw_freq_khz,
    input  wire sw_config_search_en,
    input  wire sw_config_search_up,
    input  wire sw_config_mono,
    input  wire sw_config_mute,
    input  wire sw_config_standby,
    
    // AXI Status outputs
    output wire hw_status_busy,
    output wire hw_status_done,
    output wire hw_status_station_found,
    output wire hw_status_stereo,
    output wire hw_status_scanning,
    output wire hw_status_tuned,
    output wire hw_status_search_mode,
    output wire [10:0] hw_scan_result_khz,
    output wire hw_scan_result_stereo,
    
    // Hardware interfaces
      
    // I2C
    inout  wire i2c_scl,
    inout  wire i2c_sda,
    
    // SPI
    output DC, 
    output SCL,       
    output SDA,       
    output wire nRES,
    
    // i2s
    output wire        i2s_mclk,
    input  wire        i2s_bclk,  
    input  wire        i2s_lrck,
    input  wire        i2s_din, 
    
    // AXI-Stream 
    output wire [31:0] m_axis_audio_tdata,
    output wire        m_axis_audio_tvalid,
    input  wire        m_axis_audio_tready,
    output wire        m_axis_audio_tlast,
    
    // Status LEDs
    output reg  error_led,
    output wire busy_led,
    output wire search_en_led
    
);
    
    
    // Debounce physical buttons
    wire start_db, search_en_db;
    reg start_db_d, search_en_db_d;
    debounce #(.CLK_FREQ_HZ(50000000), .DEBOUNCE_MS(10)) i_debounce0(.clk(clk), .btn_in(~start), .btn_out(start_db));
    debounce #(.CLK_FREQ_HZ(50000000), .DEBOUNCE_MS(10)) i_debounce1(.clk(clk), .btn_in(~search_en_btn), .btn_out(search_en_db));
    
    always @(posedge clk) begin
        start_db_d <= start_db;
        search_en_db_d <= search_en_db;
    end
    
    wire start_pulse_hw  = start_db & ~start_db_d;
    wire search_pulse_hw = search_en_db & ~search_en_db_d;
    
    // HW/SW control
    wire any_start = start_pulse_hw | sw_ctrl_start;
    wire toggle_search = search_pulse_hw | sw_config_search_en;

    reg combined_search_en;
    always @(posedge clk) begin
        if (!rst_n) combined_search_en <= 1'b0;
        else if (toggle_search) combined_search_en <= ~combined_search_en;
    end    
    
//    wire combined_search_en = active_search_en;
    assign search_en_led = combined_search_en;
    assign hw_status_search_mode = combined_search_en;


    reg[1:0] hw_station_idx;
    reg [10:0] active_freq_khz;        
    wire tea_done;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            hw_station_idx <= 0;
            active_freq_khz <= 11'd886;
        end else if (start_pulse_hw && !combined_search_en) begin
            hw_station_idx <= hw_station_idx + 1;
            case (hw_station_idx)
                0: active_freq_khz <= 11'd972;
                1: active_freq_khz <= 11'd1003;
                2: active_freq_khz <= 11'd1018;
                3: active_freq_khz <= 11'd886;
            endcase
        end else if (sw_ctrl_start && !combined_search_en) begin
            active_freq_khz <= sw_freq_khz;
        end else if (tea_done && combined_search_en && hw_status_station_found) begin
                active_freq_khz <= hw_scan_result_khz;            
        end
    end

    
    wire missed_ack;
    assign hw_status_done = tea_done;
    wire update_screen = tea_done;
        
    always @(posedge clk) begin
        if (!rst_n) begin
            error_led <= 1'b0;
        end else if (any_start) begin
            error_led <= 1'b0;
        end else if (missed_ack) begin
            error_led <= 1'b1;
        end
    end
    
    
    wire [10:0] display_freq = hw_status_station_found ? hw_scan_result_khz : active_freq_khz;
        
    wire bcd_fin, bcd_busy;
    wire [3:0] bcd0, bcd1, bcd2, bcd3, bcd4;
    
   
    bin_to_bcd i_bcd
    (
        .clk(clk),
        .rst_n(rst_n),

        .en(update_screen),
        .bin({5'd0, display_freq}),
        .bcd0(bcd0),
        .bcd1(bcd1),
        .bcd2(bcd2),
        .bcd3(bcd3),
        .bcd4(bcd4),

        .busy(bcd_busy),
        .fin(bcd_fin)
    );


    wire fb_we;
    wire [15:0] fb_din;
    wire [15:0] fb_waddr;
    wire [15:0] fb_raddr;
    wire [15:0] fb_dout;

    fb_bram 
        #(.W(240),.H(240))
    i_fb_bram
    (
        .clkw(clk),
        .clkr(clk),
        
        .we(fb_we),
        .din(fb_din),
        .waddr(fb_waddr),
        
        .raddr(fb_raddr),
        .dout(fb_dout)
    );

    wire render_done;
    text_renderer 
        #(.W(240), .H(240), .COLOR_FG(16'hFFFF), .COLOR_BG(16'h0000))
    i_renderer
    (
        .clk       (clk),
        .rst_n     (rst_n),

        .start_draw(bcd_fin),

        .bcd3      (bcd3),
        .bcd2      (bcd2),
        .bcd1      (bcd1),
        .bcd0      (bcd0),
        
        .we        (fb_we),
        .din       (fb_din),
        .waddr     (fb_waddr),

        .done      (render_done)
    );

    reg lcd_valid;
    wire lcd_ready;


    always @(posedge clk) begin
        if (!rst_n) lcd_valid <= 0;
        else begin
            if (render_done) lcd_valid <= 1;
            else if (lcd_ready) lcd_valid <= 0;
        end
    end

    lcd_driver 
        #(.W(240), .H(240), .FREQ_CLK(50_000_000))
    i_lcd_driver
    (
        .clk(clk),
        .rst(rst_n),

        .valid(lcd_valid),
        .ready(lcd_ready),

        .DC(DC),
        .SCL(SCL),
        .SDA(SDA),
        .nRES(nRES),

        .fb_dout(fb_dout),
        .fb_raddr(fb_raddr)
    );


    // I2C ports
    wire scl_i, scl_o, scl_t;
    wire sda_i, sda_o, sda_t;    

    IOBUF i2c_scl_iobuf (
        .IO(i2c_scl), 
        .I(scl_o),    
        .O(scl_i),    
        .T(scl_t)     
    );

    IOBUF i2c_sda_iobuf (
        .IO(i2c_sda),
        .I(sda_o),
        .O(sda_i),
        .T(sda_t)
    );

//    assign i2c_scl = scl_t ? 1'bz : scl_o;
//    assign scl_i   = i2c_scl;
//    assign i2c_sda = sda_t ? 1'bz : sda_o;
//    assign sda_i   = i2c_sda;
    
    
    tea5767_controller i_tea5767_controller(
        .clk(clk),
        .rst_n(rst_n),

        // Control (Pulses)

        .start(any_start),
        .abort(1'b0),
        .clr_done(sw_ctrl_clr_done),


        // Configuration
        .freq_khz(active_freq_khz), // [10:0] 100.5 MHz -> 1005 | 99.0 MHz -> 990
        .search_en(combined_search_en),
        .search_up(sw_config_search_up),
        .mono(sw_config_mono),
        .mute(sw_config_mute),
        .standby(sw_config_standby),

        // Status
        .busy(hw_status_busy),
        .done(tea_done),
        .station_found(hw_status_station_found),
        .stereo(hw_status_stereo),
        .scanning(hw_status_scanning),
        .tuned(hw_status_tuned),

        // Result
        .scan_result_khz(hw_scan_result_khz), // [10:0]
        .scan_result_stereo(hw_scan_result_stereo),
        .missed_ack(missed_ack),
        .i2c_error(),

        // I2C Pins
        .scl_i(scl_i),
        .scl_o(scl_o),
        .scl_t(scl_t),
        .sda_i(sda_i),
        .sda_o(sda_o),
        .sda_t(sda_t)
    );
    assign busy_led = hw_status_busy;
    
    // Audio 
    wire clk_8_192;
    // clocking wizard is set to 8.192MHz
    clk_wiz_0 u_clk_8_192(.clk_in1(clk), .clk_out1(clk_8_192));
    reg clk_4_096 = 0;
    always @(posedge clk_8_192) begin
        clk_4_096 <= ~clk_4_096;
    end
    
    assign i2s_mclk = clk_4_096;
    
    wire[23:0] audio_left;
    wire[23:0] audio_right;    

    top_i2s_rx_module #(
        .FRAME_RES(32),
        .DATA_RES(24)
    ) i_i2s_rx(
    .bck_i(i2s_bclk),
    .lrck_i(i2s_lrck), 
    .dat_i(i2s_din),
    .left_o(audio_left),
    .right_o(audio_right)
    );
    
    
    wire [7:0] compressed_audio_left;    
    wire [7:0] compressed_audio_right;    
    
    alaw_encoder alaw_inst_r(.pcm_in(audio_right[23:11]), .alaw_out(compressed_audio_right));
    alaw_encoder alaw_inst_l(.pcm_in(audio_left[23:11]),.alaw_out(compressed_audio_left));

    reg lrck_sync1, lrck_sync2;
    always @(posedge clk) begin
        lrck_sync1 <= i2s_lrck;
        lrck_sync2 <= lrck_sync1;
    end
    
    wire sample_ready_pulse = (lrck_sync2 && !lrck_sync1); 

    reg [31:0] axis_tdata_reg;
    reg        axis_tvalid_reg;
    reg        axis_tlast_reg;
    reg [8:0]  sample_counter;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            axis_tvalid_reg <= 1'b0;
            axis_tdata_reg <= 32'd0;
            axis_tlast_reg <= 1'b0;
            sample_counter <= 9'd0;
        end else begin
            if (sample_ready_pulse) begin
                axis_tvalid_reg <= 1'b1;
                axis_tdata_reg  <= {16'b0, compressed_audio_left, compressed_audio_right};
                    
                if (sample_counter == 9'd511) begin
                    axis_tlast_reg <= 1'b1;
                    sample_counter <= 9'd0;
                end else begin
                    axis_tlast_reg <= 1'b0;
                    sample_counter <= sample_counter + 1'b1;                
                end
                
            end else if (m_axis_audio_tready && axis_tvalid_reg) begin
                axis_tvalid_reg <= 1'b0;
                axis_tlast_reg  <= 1'b0;
            end
        end
    end
    
    assign m_axis_audio_tdata  = axis_tdata_reg;
    assign m_axis_audio_tvalid = axis_tvalid_reg;
    assign m_axis_audio_tlast  = axis_tlast_reg;
endmodule