//
//
// Copyright (c) 2020 Grabulosaure
//
// This program is GPL Licensed. See COPYING for the full license.
//
//
////////////////////////////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

// Modified version to display specific vertical size. // Sorgelig

module video_crop
(
	input             CLK_VIDEO,
	input             CE_PIXEL,
	input             VGA_VS,

	input             VGA_DE_IN,
	input      [11:0] ARX,
	input      [11:0] ARY,
	input       [9:0] CROP_SIZE,
	input       [4:0] CROP_OFF,

	output            VGA_DE,
	output reg [11:0] VIDEO_ARX,
	output reg [11:0] VIDEO_ARY
);

reg vde;
always @(posedge CLK_VIDEO) begin
	reg        old_de, old_vs,vcalc;
	reg  [9:0] vcpt,vsize,vcrop,voff;
	reg [11:0] vadj;
	reg [21:0] ARXI,ARYI,ARXG,ARYG,arx,ary;
	
	if (CE_PIXEL) begin
		old_de <= VGA_DE_IN;
		old_vs <= VGA_VS;
		if (VGA_VS & ~old_vs) begin
			vcpt  <= 0;
			vsize <= vcpt;
			vcalc <= 1;
			vcrop <= ((CROP_SIZE >= vcpt) || !CROP_SIZE) ? 10'd0 : CROP_SIZE;
		end
		
		if (~VGA_DE_IN & old_de) vcpt <= vcpt + 1'd1;
	end

	arx <= ARX;
	ary <= ARY;

	if(!vcrop || !ary) begin
		VIDEO_ARX <= arx[11:0];
		VIDEO_ARY <= ary[11:0];
	end
	else if (vcalc) begin
		ARXG <= arx * vsize;
		ARYG <= ary * vcrop;
		vcalc <= 0;
	end
	else if (ARXG[21] | ARYG[21]) begin
		VIDEO_ARX <= ARXG[21:10];
		VIDEO_ARY <= ARYG[21:10];
	end
	else begin
		ARXG <= ARXG << 1;
		ARYG <= ARYG << 1;
	end

	vadj <= {2'b0,vsize-vcrop} + {{6{CROP_OFF[4]}},CROP_OFF,1'b0};
	voff <= vadj[11] ? 10'd0 : ((vadj[11:1] + vcrop) > vsize) ? vsize-vcrop : vadj[10:1];
	vde  <= ((vcpt >= voff) && (vcpt < (vcrop + voff))) || !vcrop;
end

assign VGA_DE = vde & VGA_DE_IN;

endmodule
