
module ioport
(
	input        CLK,

	input        PORT_LATCH,
	input        PORT_CLK,
	output [1:0] PORT_DO,

	input	[11:0] JOYSTICK,
	input	[24:0] MOUSE,
	input        MOUSE_EN
);

assign PORT_DO = {1'b1, MOUSE_EN ? MS_LATCH[31] : JOY_LATCH[15]};

wire [15:0] JOY = {JOYSTICK[5], JOYSTICK[7], JOYSTICK[10], JOYSTICK[11], JOYSTICK[3], JOYSTICK[2],
                   JOYSTICK[1], JOYSTICK[0], JOYSTICK[4],  JOYSTICK[6],  JOYSTICK[8], JOYSTICK[9], 4'b0000};

reg [15:0] JOY_LATCH;
always @(posedge CLK) begin
	reg old_clk;
	old_clk <= PORT_CLK;
	if(PORT_LATCH) JOY_LATCH <= ~JOY;
	else if (~old_clk & PORT_CLK) JOY_LATCH <= JOY_LATCH << 1;
end

reg  [10:0] curdx;
reg  [10:0] curdy;
wire [10:0] newdx = curdx + {{3{MOUSE[4]}},MOUSE[15:8]}  + ((speed == 2) ? {{3{MOUSE[4]}},MOUSE[15:8]}  : (speed == 1) ? {{4{MOUSE[4]}},MOUSE[15:9]}  : 11'd0);
wire [10:0] newdy = curdy + {{3{MOUSE[5]}},MOUSE[23:16]} + ((speed == 2) ? {{3{MOUSE[5]}},MOUSE[23:16]} : (speed == 1) ? {{4{MOUSE[5]}},MOUSE[23:17]} : 11'd0);
wire  [6:0] dx = curdx[10] ? -curdx[6:0] : curdx[6:0];
wire  [6:0] dy = curdy[10] ? -curdy[6:0] : curdy[6:0];

reg  [1:0] speed = 0;
reg [31:0] MS_LATCH;
always @(posedge CLK) begin
	reg old_stb, old_clk, old_latch;
	reg sdx,sdy;

	old_clk <= PORT_CLK;
	old_latch <= PORT_LATCH;

	if(old_latch & ~PORT_LATCH) begin
		MS_LATCH <= ~{JOY[15:6] | MOUSE[1:0],speed,4'b0001,sdy,dy,sdx,dx};
		curdx <= 0;
		curdy <= 0;
	end
	else begin
		old_stb <= MOUSE[24];
		if(old_stb != MOUSE[24]) begin
			if($signed(newdx) > $signed(10'd127)) curdx <= 10'd127;
			else if($signed(newdx) < $signed(-10'd127)) curdx <= -10'd127;
			else curdx <= newdx;
			
			sdx <= newdx[10];

			if($signed(newdy) > $signed(10'd127)) curdy <= 10'd127;
			else if($signed(newdy) < $signed(-10'd127)) curdy <= -10'd127;
			else curdy <= newdy;

			sdy <= ~newdy[10];
		end;
	end

	if(~old_clk & PORT_CLK) begin
		if(PORT_LATCH) speed <= speed + 1'd1;
		else MS_LATCH <= MS_LATCH << 1;
	end
end

endmodule
