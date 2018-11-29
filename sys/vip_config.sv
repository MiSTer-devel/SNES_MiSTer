
module vip_config
(
	input             clk,
	input             reset,
	
	input       [7:0] ARX,
	input       [7:0] ARY,
	input             CFG_SET,

	input      [11:0] WIDTH,
	input      [11:0] HFP,
	input      [11:0] HBP,
	input      [11:0] HS,
	input      [11:0] HEIGHT,
	input      [11:0] VFP,
	input      [11:0] VBP,
	input      [11:0] VS,
	
	input      [11:0] VSET,
	input             coef_set,
	input             coef_clk,
	input       [6:0] coef_addr,
	input       [8:0] coef_data,
	input             coef_wr,
	input       [2:0] scaler_flt,

	output reg  [8:0] address,
	output reg        write,
	output reg [31:0] writedata,
	input             waitrequest
);


reg         newres = 1;

wire [21:0] init[23] =
'{
	//video mode
	{newres, 2'd2, 7'd04, 12'd0  }, //Bank
	{newres, 2'd2, 7'd30, 12'd0  }, //Valid
	{newres, 2'd2, 7'd05, 12'd0  }, //Progressive/Interlaced
	{newres, 2'd2, 7'd06, w      }, //Active pixel count
	{newres, 2'd2, 7'd07, h      }, //Active line count
	{newres, 2'd2, 7'd09, hfp    }, //Horizontal Front Porch
	{newres, 2'd2, 7'd10, hs     }, //Horizontal Sync Length
	{newres, 2'd2, 7'd11, hb     }, //Horizontal Blanking (HFP+HBP+HSync)
	{newres, 2'd2, 7'd12, vfp    }, //Vertical Front Porch
	{newres, 2'd2, 7'd13, vs     }, //Vertical Sync Length
	{newres, 2'd2, 7'd14, vb     }, //Vertical blanking (VFP+VBP+VSync)
	{newres, 2'd2, 7'd30, 12'd1  }, //Valid
	{newres, 2'd2, 7'd00, 12'd1  }, //Go

	//mixer
	{  1'd1, 2'd1, 7'd03, w      }, //Bkg Width
	{  1'd1, 2'd1, 7'd04, h      }, //Bkg Height
	{  1'd1, 2'd1, 7'd08, posx   }, //Pos X
	{  1'd1, 2'd1, 7'd09, posy   }, //Pos Y
	{  1'd1, 2'd1, 7'd10, 12'd1  }, //Enable Video 0
	{  1'd1, 2'd1, 7'd00, 12'd1  }, //Go

	//scaler
	{  1'd1, 2'd0, 7'd03, videow }, //Output Width
	{  1'd1, 2'd0, 7'd04, videoh }, //Output Height
	{  1'd1, 2'd0, 7'd00, 12'd1  }, //Go

	22'h3FFFFF
};

reg  [6:0] coef_a;
wire [8:0] coef_q;
 coeffbuf coeffbuf
(
	.wrclock(coef_clk),
	.wraddress({1'b1,coef_addr}),
	.data(coef_data),
	.wren(coef_wr),
	.rdclock(clk),
	.rdaddress({|scaler_flt,coef_a}),
	.q(coef_q)
);
reg [11:0] w;
reg [11:0] hfp;
reg [11:0] hbp;
reg [11:0] hs;
reg [11:0] hb;
reg [11:0] h;
reg [11:0] vfp;
reg [11:0] vbp;
reg [11:0] vs;
reg [11:0] vb;

reg [11:0] videow;
reg [11:0] videoh;

reg [11:0] posx;
reg [11:0] posy;

always @(posedge clk) begin
	reg  [7:0] state = 0;
	reg  [7:0] arx, ary;
	reg  [7:0] arxd, aryd;
	reg [11:0] vset, vsetd;
	reg        cfg, cfgd;
	reg [31:0] wcalc;
	reg [31:0] hcalc;
	reg [12:0] timeout = 0;
	reg  [4:0] coef_state = 0;
	reg  [6:0] coef_n;
	reg        coef_setd;
	reg        bank = 0;

	arxd  <= ARX;
	aryd  <= ARY;
	vsetd <= VSET;
	coef_setd <= coef_set;
	
	cfg   <= CFG_SET;
	cfgd  <= cfg;

	if(reset || (arx != arxd) || (ary != aryd) || (vset != vsetd) || (~cfgd && cfg) || (coef_setd ^ coef_set)) begin
		arx <= arxd;
		ary <= aryd;
		vset <= vsetd;
		timeout <= '1;
		state <= 0;
		if(reset || (~cfgd && cfg)) newres <= 1;
	end
	else
	if(timeout > 0)
	begin
		timeout <= timeout - 1'd1;
		state <= 1;
		if(!(timeout & 'h1f)) case(timeout>>5)
			5:	begin
					w   <= WIDTH;
					hfp <= HFP;
					hbp <= HBP;
					hs  <= HS;
					h   <= HEIGHT;
					vfp <= VFP;
					vbp <= VBP;
					vs  <= VS;
				end
			4: begin
					hb  <= hfp+hbp+hs;
					vb  <= vfp+vbp+vs;
				end
			3: begin
					wcalc <= vset ? (vset*arx)/ary : (h*arx)/ary;
					hcalc <= (w*ary)/arx;
				end
			2: begin
					videow <= (!vset && (wcalc > w))    ? w : wcalc[11:0];
					videoh <= vset ? vset : (hcalc > h) ? h : hcalc[11:0];
				end
			1: begin
					posx <= (w - videow)>>1;
					posy <= (h - videoh)>>1;
				end
		endcase
	end
	else
if(~waitrequest)
	begin

		write <= 0;
if(state) begin
			state <= state + 1'd1;
		if((state&3)==3) begin
			if(init[state>>2] == 22'h3FFFFF) begin
				state  <= 0;
				newres <= 0;
					coef_state <= 1;
					coef_a <= 0;
			end
			else begin
				writedata <= 0;
				{write, address, writedata[11:0]} <= init[state>>2];
				end
			end
		end
else begin
			case(coef_state)
				1,3: coef_state <= coef_state + 1'd1;
				2: begin
						address <= 8;
						writedata <= 0;
						writedata[0] <= bank;
						write <= 1;
						coef_state <= coef_state + 1'd1;
					end
				4: begin
						address <= 10;
						writedata <= 0;
						writedata[0] <= bank;
						write <= 1;
						coef_state <= coef_state + 1'd1;
					end
				5,7,9,11: coef_state <= coef_state + 1'd1;
				6,8,10,12:
					begin
						coef_state <= coef_state + 1'd1;
						coef_a <= coef_a + 1'd1;
						coef_n <= coef_a;
						address <= 9'd14 + coef_a[1:0];
						writedata <= coef_q;
						write <= 1;
					end
				13: begin
						coef_state <= (&coef_n) ? 5'd14 : 5'd5;
						address <= 9'd12 + coef_n[6];
						writedata <= coef_n[5:2];
						write <= 1;
					end
				14,16: coef_state <= coef_state + 1'd1;
				15: begin
						address <= 9;
						writedata <= 0;
						writedata[0] <= bank;
						write <= 1;
						coef_state <= coef_state + 1'd1;
					end
				17: begin
						address <= 11;
						writedata <= 0;
						writedata[0] <= bank;
						write <= 1;
						bank <= ~bank;
						coef_state <= coef_state + 1'd1;
					end
				18: coef_state <= 0;
			endcase;
		end		
	end
end

endmodule
module coeffbuf
(
	input	      wrclock,
	input	[7:0] wraddress,
	input	[8:0] data,
	input	      wren,
	input	      rdclock,
	input	[7:0] rdaddress,
	output[8:0] q
);
 altsyncram	altsyncram_component (
			.address_a (wraddress),
			.address_b (rdaddress),
			.clock0 (wrclock),
			.clock1 (rdclock),
			.data_a (data),
			.wren_a (wren),
			.q_b (q),
			.aclr0 (1'b0),
			.aclr1 (1'b0),
			.addressstall_a (1'b0),
			.addressstall_b (1'b0),
			.byteena_a (1'b1),
			.byteena_b (1'b1),
			.clocken0 (1'b1),
			.clocken1 (1'b1),
			.clocken2 (1'b1),
			.clocken3 (1'b1),
			.data_b ({9{1'b1}}),
			.eccstatus (),
			.q_a (),
			.rden_a (1'b1),
			.rden_b (1'b1),
			.wren_b (1'b0));
defparam
	altsyncram_component.address_aclr_b = "NONE",
	altsyncram_component.address_reg_b = "CLOCK1",
	altsyncram_component.clock_enable_input_a = "BYPASS",
	altsyncram_component.clock_enable_input_b = "BYPASS",
	altsyncram_component.clock_enable_output_b = "BYPASS",
	altsyncram_component.intended_device_family = "Cyclone V",
	altsyncram_component.lpm_type = "altsyncram",
	altsyncram_component.numwords_a = 256,
	altsyncram_component.numwords_b = 256,
	altsyncram_component.operation_mode = "DUAL_PORT",
	altsyncram_component.outdata_aclr_b = "NONE",
	altsyncram_component.outdata_reg_b = "UNREGISTERED",
	altsyncram_component.init_file = "coeff.mif", 
	altsyncram_component.power_up_uninitialized = "FALSE",
	altsyncram_component.widthad_a = 8,
	altsyncram_component.widthad_b = 8,
	altsyncram_component.width_a = 9,
	altsyncram_component.width_b = 9,
	altsyncram_component.width_byteena_a = 1;
 endmodule
