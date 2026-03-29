module font_rom (
	input             clk,
	input      [11:0] addr, // 7 bits ASCII code + 4 bits for row (0-15)
	output reg [7:0]  data
);


(* rom_style = "block" *) reg [7:0] rom [0:4095];

initial begin
	$readmemh("font8x16.mem", rom);
end

always @(posedge clk) begin
	data <= rom[addr];
end

endmodule