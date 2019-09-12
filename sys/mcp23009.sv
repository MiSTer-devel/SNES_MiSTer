//
// MCP23009
// (C) 2019 Alexey Melnikov
//
module mcp23009
(
	input            clk,

	output reg [2:0] btn,
	input      [2:0] led,
	output reg       sd_cd,

	output		     scl,
	inout 		     sda
);


reg        start = 0;
wire       ready;
wire       error;
reg        rw;
wire [7:0] dout;
reg [15:0] din;

i2c_master #(50_000_000, 500_000) i2c
(
	.clk(clk),
	.rst(0),
	.addr('h20),
	.data_in(din),
	.start(start),
	.rw(rw),
	.error(error),
	
	.data_out(dout),
	.ready(ready),

	.i2c_sda(sda),
	.i2c_scl(scl)
);

always@(posedge clk) begin
	reg  [3:0] idx = 0;
	reg  [1:0] state = 0;
	reg [15:0] timeout = 0;

	if(~&timeout) begin
		timeout <= timeout + 1'd1;
		start   <= 0;
		state   <= 0;
		idx     <= 0;
		btn     <= 0;
		rw      <= 0;
		sd_cd   <= 1;
	end
	else begin
		if(~&init_data[idx]) begin
			case(state)
			0:	begin
					start <= 1;
					state <= 1;
					din   <= init_data[idx];
				end
			1: if(~ready) state <= 2;
			2:	begin
					start <= 0;
					if(ready) begin
						state <= 0;
						if(!error) idx <= idx + 1'd1;
					end
				end
			endcase
		end
		else begin
			case(state)
			0:	begin
					start <= 1;
					state <= 1;
					din   <= {8'h09,5'b00000,led};
				end
			1: if(~ready) state <= 2;
			2:	begin
					start <= 0;
					if(ready) begin
						state <= 0;
						rw <= 0;
						if(!error) begin
							if(rw) {sd_cd, btn} <= {dout[7], dout[5:3]};
							rw <= ~rw;
						end
					end
				end
			endcase
		end
	end
end

wire [15:0] init_data[12] = 
'{
	16'h00F8,
	16'h0138,
	16'h0200,
	16'h0300,
	16'h0400,
	16'h0524,
	16'h06FF,
	16'h0700,
	16'h0800,
	16'h0900,
	16'h0A00,
	16'hFFFF
};

endmodule
