module alaw_encoder (
		
	input [12:0]     pcm_in,

	output [7:0]     alaw_out
);

	
	wire signed [12:0] pcm = pcm_in;
	wire [11:0] abs_value = pcm[12] ? (~pcm + 1) : pcm;



	reg[2:0] exp;
	reg[3:0] mant;

	always @(*) begin
		if      (abs_value[11]) begin exp = 3'd7; mant = abs_value[10:7]; end
		else if (abs_value[10]) begin exp = 3'd6; mant = abs_value[9:6];  end
		else if (abs_value[9])  begin exp = 3'd5; mant = abs_value[8:5];  end
		else if (abs_value[8])  begin exp = 3'd4; mant = abs_value[7:4];  end
		else if (abs_value[7])  begin exp = 3'd3; mant = abs_value[6:3];  end
		else if (abs_value[6])  begin exp = 3'd2; mant = abs_value[5:2];  end
		else if (abs_value[5])  begin exp = 3'd1; mant = abs_value[4:1];  end
		else                    begin exp = 3'd0; mant = abs_value[4:1];  end
	end


	// We use sign=0 for negative, sign=1 for positive due to G.711 specification
	assign alaw_out = ({~pcm[12], exp, mant} ^ 8'h55);

endmodule