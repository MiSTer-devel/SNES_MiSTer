
module lightgun
(
	input        CLK,

	input  [7:0] JOY_X,JOY_Y,
	input        F,C,T,P,

	input        HDE,VDE,
	input        CLKPIX,
	
	output [2:0] TARGET,

	input        PORT_LATCH,
	input        PORT_CLK,
	output       PORT_P6,
	output [1:0] PORT_DO
);

assign PORT_DO = {1'b1, JOY_LATCH0[15]};

reg Ttr = 0;
reg Fb = 0, Pb = 0;

reg [15:0] JOY_LATCH0;
always @(posedge CLK) begin
	reg old_clk, old_f, old_p, old_t, old_latch;
	old_clk <= PORT_CLK;

	old_latch <= PORT_LATCH;
	if(old_latch & ~PORT_LATCH) begin
		Pb <= 0;
		if(~Ttr) Fb <= 0;
	end

	old_t <= T;
	if(~old_t & T) Ttr <=~Ttr;

	old_f <= F;
	if(~old_f & F) Fb <= 1;
	if(old_f & ~F) Fb <= 0;
	
	old_p <= P;
	if(~old_p & P) Pb <= 1;
	
	if(PORT_LATCH) JOY_LATCH0 <= ~{Fb,C,Ttr,Pb,2'b00,1'b0,1'b0,4'b1111,4'b1111};
	else if (~old_clk & PORT_CLK) JOY_LATCH0 <= JOY_LATCH0 << 1;
end

reg [8:0] hcnt;
reg [8:0] vcnt;

wire [8:0] lg_x = {~JOY_X[7], JOY_X[6:0]};
wire [8:0] lg_y = {~JOY_Y[7], JOY_Y[6:0]} - 8'd8;

always @(posedge CLK) begin
	reg old_pix, old_vde, old_hde;
	
	old_hde <= HDE;
	
	old_pix <= CLKPIX;
	if(~old_pix & CLKPIX) begin
		if(~&hcnt) hcnt <= hcnt + 1'd1;
		if(~old_hde & HDE) begin
			hcnt <= 0;
			
			old_vde <= VDE;
			if(~&vcnt) vcnt <= vcnt + 1'd1;
			if(~old_vde & VDE) vcnt <= 0;
		end
	end
	
	PORT_P6 <= ~(HDE && VDE && lg_x == hcnt && lg_y == vcnt);
	
	TARGET <= 0;
	if($signed(lg_x) >= $signed(hcnt - 3'd3) && $signed(lg_x) <= $signed(hcnt + 3'd3) && lg_y == vcnt) TARGET <= 1;
	if($signed(lg_y) >= $signed(vcnt - 3'd3) && $signed(lg_y) <= $signed(vcnt + 3'd3) && lg_x == hcnt) TARGET <= 1;
end

endmodule
