
`timescale 1 ns / 1 ps

	module fm_radio_ctrl #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 5,

		// Parameters of Axi Slave Bus Interface S_AXI_INTR
		parameter integer C_S_AXI_INTR_DATA_WIDTH	= 32,
		parameter integer C_S_AXI_INTR_ADDR_WIDTH	= 5,
		parameter integer C_NUM_OF_INTR	= 1,
		parameter  C_INTR_SENSITIVITY	= 32'hFFFFFFFF,
		parameter  C_INTR_ACTIVE_STATE	= 32'hFFFFFFFF,
		parameter integer C_IRQ_SENSITIVITY	= 1,
		parameter integer C_IRQ_ACTIVE_STATE	= 1
	)
	(
		// Users to add ports here
      
        // Physical buttons
        input  wire rst_n,
        input  wire start,
        input  wire search_en_btn,
        

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
        output wire  error_led,
        output wire busy_led,
        output wire search_en_led,     

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready,

		// Ports of Axi Slave Bus Interface S_AXI_INTR
		input wire  s_axi_intr_aclk,
		input wire  s_axi_intr_aresetn,
		input wire [C_S_AXI_INTR_ADDR_WIDTH-1 : 0] s_axi_intr_awaddr,
		input wire [2 : 0] s_axi_intr_awprot,
		input wire  s_axi_intr_awvalid,
		output wire  s_axi_intr_awready,
		input wire [C_S_AXI_INTR_DATA_WIDTH-1 : 0] s_axi_intr_wdata,
		input wire [(C_S_AXI_INTR_DATA_WIDTH/8)-1 : 0] s_axi_intr_wstrb,
		input wire  s_axi_intr_wvalid,
		output wire  s_axi_intr_wready,
		output wire [1 : 0] s_axi_intr_bresp,
		output wire  s_axi_intr_bvalid,
		input wire  s_axi_intr_bready,
		input wire [C_S_AXI_INTR_ADDR_WIDTH-1 : 0] s_axi_intr_araddr,
		input wire [2 : 0] s_axi_intr_arprot,
		input wire  s_axi_intr_arvalid,
		output wire  s_axi_intr_arready,
		output wire [C_S_AXI_INTR_DATA_WIDTH-1 : 0] s_axi_intr_rdata,
		output wire [1 : 0] s_axi_intr_rresp,
		output wire  s_axi_intr_rvalid,
		input wire  s_axi_intr_rready,
		output wire  irq
	);
	
    wire [31:0] sw_ctrl_reg;
    wire [31:0] sw_freq100khz_reg;
    wire [31:0] sw_config_reg;

    wire [31:0] hw_status_reg;
    wire [31:0] hw_scan_result_reg;
	
	wire hw_status_busy;
    wire hw_status_done;
    wire hw_status_station_found;
    wire hw_status_stereo;
    wire hw_status_scanning;
    wire hw_status_tuned;
	
    wire hw_scan_result_stereo;
    wire [10:0] hw_scan_result_khz;
        
    assign hw_status_reg = {26'd0, hw_status_tuned, hw_status_scanning, hw_status_stereo, 
                            hw_status_station_found, hw_status_done, hw_status_busy};
    
    assign hw_scan_result_reg = {20'd0, hw_scan_result_stereo, hw_scan_result_khz};
    
// Instantiation of Axi Bus Interface S00_AXI
	fm_radio_ctrl_slave_lite_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) fm_radio_ctrl_slave_lite_v1_0_S00_AXI_inst (
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready),
		
		.hw_status_reg(hw_status_reg),
        .hw_scan_result_reg(hw_scan_result_reg),
        .sw_ctrl_reg(sw_ctrl_reg),
        .sw_freq100khz_reg(sw_freq100khz_reg),
        .sw_config_reg(sw_config_reg)
	);

	// Add user logic here
	 
    wire sw_ctrl_irq_en = sw_ctrl_reg[3];    
    assign irq = hw_status_done & sw_ctrl_irq_en;
    
    
    wire sw_ctrl_start        = sw_ctrl_reg[0];
    wire sw_ctrl_reset_n      = s00_axi_aresetn & ~sw_ctrl_reg[1];
    wire sw_ctrl_clr_done     = sw_ctrl_reg[2];
    wire [10:0] sw_freq100khz = sw_freq100khz_reg[10:0];
    wire sw_config_mute       = sw_config_reg[0];
    wire sw_config_mono       = sw_config_reg[1];
    wire sw_config_search_en  = sw_config_reg[2];
    wire sw_config_search_up         = sw_config_reg[3];
    wire sw_config_standby    = sw_config_reg[4];        
   
    wire master_rst_n = rst_n &&  sw_ctrl_reset_n;
       
    top u_top(
    .clk(s00_axi_aclk),
    .rst_n(master_rst_n),     
    
    .start(start),
    .search_en_btn(search_en_btn),
    
    // AXI Control inputs
    .sw_ctrl_start(sw_ctrl_start),
    .sw_ctrl_clr_done(sw_ctrl_clr_done),
    .sw_freq_khz(sw_freq100khz),
    .sw_config_search_en(sw_config_search_en),
    .sw_config_search_up(sw_config_search_up),
    .sw_config_mono(sw_config_mono),
    .sw_config_mute(sw_config_mute),
    .sw_config_standby(sw_config_standby),
    
    // AXI Status outputs
    .hw_status_busy(hw_status_busy),
    .hw_status_done(hw_status_done),
    .hw_status_station_found(hw_status_station_found),
    .hw_status_stereo(hw_status_stereo),
    .hw_status_scanning(hw_status_scanning),
    .hw_status_tuned(hw_status_tuned),
    .hw_scan_result_khz(hw_scan_result_khz),
    .hw_scan_result_stereo(hw_scan_result_stereo),
  
    
    // Hardware interfaces
      
    // I2C
    .i2c_scl(i2c_scl),
    .i2c_sda(i2c_sda),
    
    // SPI
    .DC(DC), 
    .SCL(SCL),       
    .SDA(SDA),       
    .nRES(nRES),
    
    // i2s
    .i2s_mclk(i2s_mclk),
    .i2s_bclk(i2s_bclk),  
    .i2s_lrck(i2s_lrck),
    .i2s_din(i2s_din), 
    
    // AXI-Stream 
    .m_axis_audio_tdata(m_axis_audio_tdata),
    .m_axis_audio_tvalid(m_axis_audio_tvalid),
    .m_axis_audio_tready(m_axis_audio_tready),
    .m_axis_audio_tlast(m_axis_audio_tlast),
    
    // Status LEDs
    .error_led(error_led),
    .busy_led(busy_led),
    .search_en_led(search_en_led)
);
    
	// User logic ends

	endmodule
