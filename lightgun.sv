
module lightgun
(
	input        CLK,
	input        RESET,

	input [24:0] MOUSE,
	input        MOUSE_XY,

	input  [7:0] JOY_X,JOY_Y,
	input        F,C,T,P,

	input        HDE,VDE,
	input        CLKPIX,
	
	output [2:0] TARGET,
	input        SIZE,

	input        PORT_LATCH,
	input        PORT_CLK,
	output       PORT_P6,
	output [1:0] PORT_DO
);

parameter CROSS_SZ = 8'd3;

assign PORT_DO = {1'b1, JOY_LATCH0[7]};
assign TARGET  = {{2{~Ttr & ~offscreen & draw}}, Ttr & ~offscreen & draw};

reg Ttr; // 0 - one-shot fire. 1 - continous fire.
reg Fb = 0, Pb = 0;

reg [7:0] JOY_LATCH0;
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
	if(RESET) Ttr <= 1;

	old_f <= F;
	if(~old_f & F) Fb <= 1;
	if(old_f & ~F) Fb <= 0;
	
	old_p <= P;
	if(~old_p & P) Pb <= 1;
	
	if(PORT_LATCH) JOY_LATCH0 <= ~{Fb,C,Ttr,Pb,2'b00,offscreen,1'b0};
	else if (~old_clk & PORT_CLK) JOY_LATCH0 <= JOY_LATCH0 << 1;
end

reg  [8:0] lg_x, lg_y, x, y;

wire [9:0] new_x = {lg_x[8],lg_x} + {{2{MOUSE[4]}},MOUSE[15:8]};
wire [9:0] new_y = {lg_y[8],lg_y} - {{2{MOUSE[5]}},MOUSE[23:16]};

wire [8:0] j_x = {~JOY_X[7], JOY_X[6:0]};
wire [8:0] j_y = {~JOY_Y[7], JOY_Y[6:0]};

reg offscreen = 0, draw = 0;
always @(posedge CLK) begin
	reg old_pix, old_hde, old_vde, old_ms;
	reg [8:0] hcnt, vcnt;
	reg [8:0] vtotal;
	reg [15:0] hde_d;
	reg [8:0] xm,xp,ym,yp;
	
	old_ms <= MOUSE[24];
	if(MOUSE_XY) begin
		if(old_ms ^ MOUSE[24]) begin
			if(new_x[9]) lg_x <= 0;
			else if(new_x[8]) lg_x <= 255;
			else lg_x <= new_x[8:0];

			if(new_y[9]) lg_y <= 0;
			else if(new_y > vtotal) lg_y <= vtotal;
			else lg_y <= new_y[8:0];
		end
	end
	else begin
		lg_x <= j_x;
		if(j_y < 8) lg_y <= 0;
		else if((j_y - 9'd8) > vtotal) lg_y <= vtotal;
		else lg_y <= j_y - 9'd8;
	end

	old_pix <= CLKPIX;
	if(~old_pix & CLKPIX) begin
		hde_d <= {hde_d[14:0],HDE};
		old_hde <= hde_d[15];
		if(~&hcnt) hcnt <= hcnt + 1'd1;
		if(~old_hde & ~HDE) hcnt <= 0;
		if(old_hde & ~hde_d[15]) begin
			if(~VDE) begin
				vcnt <= 0;
				if(vcnt) vtotal <= vcnt - 1'd1;
			end
			else if(~&vcnt) vcnt <= vcnt + 1'd1;
		end
		
		old_vde <= VDE;
		if(~old_vde & VDE) begin
			x  <= lg_x;
			y  <= lg_y;
			xm <= lg_x - CROSS_SZ;
			xp <= lg_x + CROSS_SZ;
			ym <= lg_y - CROSS_SZ;
			yp <= lg_y + CROSS_SZ;
			offscreen <= !lg_y[7:1] || lg_y >= (vtotal-1'd1) || !lg_x[7:1] || &lg_x[7:1];
		end
	end

	PORT_P6 <= ~(HDE && VDE && x == hcnt && y == vcnt);
	draw <= (((SIZE || ($signed(hcnt) >= $signed(xm) && hcnt <= xp)) && y == vcnt) || 
	         ((SIZE || ($signed(vcnt) >= $signed(ym) && vcnt <= yp)) && x == hcnt));
end

endmodule
