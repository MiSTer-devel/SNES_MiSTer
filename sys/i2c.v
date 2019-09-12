module i2c_master
(
	input            clk,
	input            rst,
	input      [6:0] addr,
	input     [15:0] data_in,
	input            start,
	input            rw,

	output reg       error,
	
	output reg [7:0] data_out,
	output reg       ready,

	inout            i2c_sda,
	output           i2c_scl
);

parameter CLK_Freq = 50_000_000;	//	50 MHz
parameter I2C_Freq = 400_000;		//	400 KHz

localparam IDLE        = 0;
localparam START       = 1;
localparam ADDRESS     = 2;
localparam READ_ACK    = 3;
localparam WRITE_DATA  = 4;
localparam WRITE_DATA2 = 5;
localparam WRITE_ACK   = 6;
localparam READ_DATA   = 7;
localparam READ_ACK2   = 8;
localparam READ_ACK3   = 9;
localparam STOP        = 10;
localparam STOP2       = 11;

localparam I2C_Rate = CLK_Freq/(I2C_Freq*2);

assign i2c_scl = scl_disable | i2c_clk;
assign i2c_sda = ~sda_out ? 1'b0 : 1'bz;

reg i2c_clk;
reg i2c_clk_d;
always@(posedge clk) begin
	integer div = 0;
	if(div < I2C_Rate) begin
		div <= div + 1;
	end else	begin
		div <= 0;
		i2c_clk <= ~i2c_clk;
	end
	i2c_clk_d <= i2c_clk;
end

reg sda_out     = 1;
reg scl_disable = 0;

always @(posedge clk, posedge rst) begin
	reg [3:0] state;
	reg [7:0] saved_addr;
	reg [7:0] saved_data1;
	reg [7:0] saved_data2;
	reg [2:0] counter;
	reg       old_st;

	if(rst) begin
		state <= IDLE;
		scl_disable <= 1;
		sda_out <= 1;
		ready <= 0;
	end		
	else begin
		if(i2c_clk & ~i2c_clk_d) begin
			old_st <= start;

			case(state)
			
				IDLE: begin
					ready <= 1;
					if (~old_st & start) begin
						state <= START;
						saved_addr <= {addr, rw};
						{saved_data1,saved_data2} <= data_in;
						error <= 0;
						ready <= 0;
					end
				end

				START: begin
					scl_disable <= 0;
					counter <= 7;
					state <= ADDRESS;
				end

				ADDRESS: begin
					if (counter == 0) begin 
						state <= READ_ACK;
					end else counter <= counter - 1'd1;
				end

				READ_ACK: begin
					if (i2c_sda == 0) begin
						counter <= 7;
						if(saved_addr[0] == 0) state <= WRITE_DATA;
						else state <= READ_DATA;
					end
					else begin
						state <= STOP;
						error <= 1;
					end
				end

				WRITE_DATA: begin
					if(counter == 0) begin
						state <= READ_ACK2;
					end else counter <= counter - 1'd1;
				end
				
				READ_ACK2: begin
					if (i2c_sda == 0) begin
						state <= WRITE_DATA2;
						counter <= 7;
					end
					else begin
						state <= STOP;
						error <= 1;
					end
				end

				WRITE_DATA2: begin
					if(counter == 0) state <= READ_ACK3;
					else counter <= counter - 1'd1;
				end

				READ_ACK3: begin
					if (i2c_sda == 0) state <= STOP;
					else begin
						state <= STOP;
						error <= 1;
					end
				end

				READ_DATA: begin
					data_out[counter] <= i2c_sda;
					if (counter == 0) state <= WRITE_ACK;
					else counter <= counter - 1'd1;
				end
				
				WRITE_ACK: begin
					state <= STOP;
				end

				STOP: begin
					scl_disable <= 1;
					state <= STOP2;
				end

				STOP2: begin
					state <= IDLE;
				end
			endcase
		end

		if(~i2c_clk & i2c_clk_d) begin
			case(state)
				START:       sda_out <= 0;
				ADDRESS:     sda_out <= saved_addr[counter];
				READ_ACK:    sda_out <= 1;
				READ_ACK2:   sda_out <= 1;
				READ_ACK3:   sda_out <= 1;
				WRITE_DATA:  sda_out <= saved_data1[counter];
				WRITE_DATA2: sda_out <= saved_data2[counter];
				WRITE_ACK:   sda_out <= 0;
				READ_DATA:   sda_out <= 1;
				STOP:        sda_out <= 0;
				STOP2:       sda_out <= 1;
			endcase
		end
	end
end

endmodule
