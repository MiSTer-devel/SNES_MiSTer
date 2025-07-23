module ioport
(
	input        CLK,

	input        MULTITAP,

	input        PORT_LATCH,
	input        PORT_CLK,
	input        PORT_P6,
	output [1:0] PORT_DO,
	output [15:0] JOYSTICK1_RUMBLE,  // 15:8 - 'large' rumble motor magnitude, 7:0 'small' rumble motor magnitude
	input	[11:0] JOYSTICK1,
	input	[11:0] JOYSTICK2,
	input	[11:0] JOYSTICK3,
	input	[11:0] JOYSTICK4,

	input	[24:0] MOUSE,
	input        MOUSE_EN
);

assign PORT_DO = {(JOY_LATCH1[15] & ~PORT_LATCH) | ~MULTITAP, MOUSE_EN ? MS_LATCH[31] : JOY_LATCH0[15]};

wire [11:0] JOYSTICK[4] = '{JOYSTICK1,JOYSTICK2,JOYSTICK3,JOYSTICK4};

wire JOYn = ~PORT_P6 & MULTITAP;

wire [15:0] JOY0 = {JOYSTICK[{JOYn,1'b0}][5],  JOYSTICK[{JOYn,1'b0}][7],
                    JOYSTICK[{JOYn,1'b0}][10], JOYSTICK[{JOYn,1'b0}][11],
                    JOYSTICK[{JOYn,1'b0}][3],  JOYSTICK[{JOYn,1'b0}][2],
                    JOYSTICK[{JOYn,1'b0}][1],  JOYSTICK[{JOYn,1'b0}][0],
                    JOYSTICK[{JOYn,1'b0}][4],  JOYSTICK[{JOYn,1'b0}][6],
                    JOYSTICK[{JOYn,1'b0}][8],  JOYSTICK[{JOYn,1'b0}][9], 4'b0000};

wire [15:0] JOY1 = {JOYSTICK[{JOYn,1'b1}][5],  JOYSTICK[{JOYn,1'b1}][7],
                    JOYSTICK[{JOYn,1'b1}][10], JOYSTICK[{JOYn,1'b1}][11],
                    JOYSTICK[{JOYn,1'b1}][3],  JOYSTICK[{JOYn,1'b1}][2],
                    JOYSTICK[{JOYn,1'b1}][1],  JOYSTICK[{JOYn,1'b1}][0],
                    JOYSTICK[{JOYn,1'b1}][4],  JOYSTICK[{JOYn,1'b1}][6],
                    JOYSTICK[{JOYn,1'b1}][8],  JOYSTICK[{JOYn,1'b1}][9], 4'b0000};

reg [15:0] JOY_LATCH0;
always @(posedge CLK) begin
	reg old_clk, old_n;
	old_clk <= PORT_CLK;
	old_n <= JOYn;
	if(PORT_LATCH | (~old_n & JOYn)) JOY_LATCH0 <= ~JOY0;
	else if (~old_clk & PORT_CLK) JOY_LATCH0 <= JOY_LATCH0 << 1;
end

reg [15:0] JOY_LATCH1;
always @(posedge CLK) begin
	reg old_clk, old_n;
	old_clk <= PORT_CLK;
	old_n <= JOYn;
	if(PORT_LATCH | (~old_n & JOYn)) JOY_LATCH1 <= ~JOY1;
	else if (~old_clk & PORT_CLK) JOY_LATCH1 <= JOY_LATCH1 << 1;
end

// Rumble Support
// only Port 1 (JOYn==0) ever drives rumble
wire doing_port1 = ~MULTITAP || (MULTITAP && (JOYn == 1'b0));

// shift‑in window to spot 0x72
localparam [7:0] RUMBLE_SENTRY = 8'h72;
reg  [15:0] shift16;
reg  [15:0] current_rumble;
reg         prev_clk, prev_latch;

always @(posedge CLK) begin
  // sample the raw lines
  prev_clk   <= PORT_CLK;
  prev_latch <= PORT_LATCH;

  // on P/S Out falling edge: new frame → clear everything
  if (prev_latch & ~PORT_LATCH) begin
    shift16        <= 16'h0000;
    current_rumble <= 16'h0000;
  end

  // during frame (PORT_LATCH low), only for Port 1, shift in each PORT_CLK rising
  if (~prev_clk & PORT_CLK && ~PORT_LATCH && doing_port1) begin
    shift16 <= { shift16[14:0], PORT_P6 };
  end

  // whenever the top‑byte matches 0x72, latch the low nibble intensities
  if (shift16[15:8] == RUMBLE_SENTRY && doing_port1) begin
    // expand 4‑bit to 8‑bit by duplicating nibble
    current_rumble[15:8] <= { shift16[7:4], shift16[7:4] };   // large motor
    current_rumble[ 7:0] <= { shift16[3:0], shift16[3:0] };   // small motor
  end
end

// drive out the two‑byte rumble word
assign JOYSTICK1_RUMBLE = current_rumble;

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
		MS_LATCH <= ~{8'h00, MOUSE[1:0],speed,4'b0001,sdy,dy,sdx,dx};
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
		if(PORT_LATCH) begin
			speed <= speed + 1'd1;
			if(speed == 2) speed <= 0;
		end
		else MS_LATCH <= MS_LATCH << 1;
	end
end

endmodule