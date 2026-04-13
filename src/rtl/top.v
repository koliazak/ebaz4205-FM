`timescale 1ns / 1ps

module top (
    input  wire clk,
    input  wire rst_n,     
    
    input  wire start,
    input  wire search_en_btn,
    
    inout  wire i2c_scl,
    inout  wire i2c_sda,

    output DC, 
    output SCL,       
    output SDA,       
    output wire nRES,

    output reg  error_led,
    output wire busy_led,
    output wire search_en_led,
    
    
    output wire        i2s_mclk,
    input  wire        i2s_bclk,  
    input  wire        i2s_lrck,
    input  wire        i2s_din 
    

);


    wire start_db, search_en_db;
    reg search_en_db_d, start_db_d;
    debounce_0 i_debounce0(.clk(clk), .btn_in(~start), .btn_out(start_db));
    debounce_0 i_debounce1(.clk(clk), .btn_in(~search_en_btn), .btn_out(search_en_db));
    always @(posedge clk) begin
        start_db_d <= start_db;
        search_en_db_d <= search_en_db;
    end
    
    wire start_pulse = start_db & ~start_db_d;
    wire search_pulse = search_en_db & ~search_en_db_d;

    reg search_en;
    reg[1:0] station;
    reg [10:0] freq_khz;

    assign search_en_led = search_en;
    

    wire tea_done;
    wire [10:0] scan_result_khz;
    wire missed_ack;
    wire update_screen = tea_done;

    
    always @(posedge clk) begin
        if (!rst_n) begin
            search_en <= 0;
            station <= 0;
            freq_khz <= 11'd886;
        end else begin 
            if (start_pulse) begin
                if (search_en) begin
                    freq_khz <= scan_result_khz;    
                end else begin 
                    station <= station + 1;
                    case (station)
                        0: freq_khz <= 11'd972;
                        1: freq_khz <= 11'd1003;
                        2: freq_khz <= 11'd1018;
                        3: freq_khz <= 11'd886;
                    endcase          
                end
            end
            if (search_pulse) begin
                search_en <= !search_en;
            end
        end         
    end

    
    always @(posedge clk) begin
        if (!rst_n) begin
            error_led <= 1'b0;
        end else if (start_pulse) begin
            error_led <= 1'b0;
        end else if (missed_ack) begin
            error_led <= 1'b1;
        end
    end
    
    
        
    wire bcd_fin, bcd_busy;
    wire [3:0] bcd0, bcd1, bcd2, bcd3, bcd4;

    bin_to_bcd i_bcd
    (
        .clk(clk),
        .rst_n(rst_n),

        .en(update_screen),
        .bin({5'd0, freq_khz}),
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
            if (!rst_n) begin
            lcd_valid <= 0;
        end else begin
            if (render_done) begin
                lcd_valid <= 1;
            end else if (lcd_ready) begin
                lcd_valid <= 0;
            end
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
    assign i2c_scl = scl_t ? 1'bz : scl_o;
    assign scl_i   = i2c_scl;
    assign i2c_sda = sda_t ? 1'bz : sda_o;
    assign sda_i   = i2c_sda;

    tea5767_controller i_tea5767_controller(
        .clk(clk),
        .rst_n(rst_n),

        // Control (Pulses)

        .start(start_pulse),
        .abort(1'b0),
        .clr_done(1'b0),


        // Configuration
        .freq_khz(freq_khz), // [10:0] 100.5 MHz -> 1005 | 99.0 MHz -> 990
        .search_en(search_en),
        .search_up(1'b1),
        .mono(1'b0),
        .mute(1'b0),
        .standby(1'b0),

        // Status
        .busy(busy_led),
        .done(tea_done),
        .station_found(),
        .stereo(),
        .scanning(),
        .tuned(),


        // Result
        .scan_result_khz(scan_result_khz), // [10:0]
        .scan_result_stereo(),
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
    ) u_i2s_rx(
    .bck_i(i2s_bclk),
    .lrck_i(i2s_lrck), 
    .dat_i(i2s_din),
    .left_o(audio_left),
    .right_o(audio_right)
    );
    
    
    (* mark_debug = "true" *) wire [7:0] compressed_audio_left;    
    (* mark_debug = "true" *) wire [7:0] compressed_audio_right;    
    
    alaw_encoder alaw_inst1(
	   .pcm_in(audio_right[23:11]),
	   .alaw_out(compressed_audio_right)
    );
    
    alaw_encoder alaw_inst2(
	   .pcm_in(audio_left[23:11]),
	   .alaw_out(compressed_audio_left)
    );

    
endmodule