module shadowmask
(
    input             clk,
    input             clk_sys,
	 
    input             cmd_wr,
    input      [15:0] cmd_in,

    input      [23:0] din,
    input             hs_in,vs_in,
    input             de_in,

    output reg [23:0] dout,
    output reg        hs_out,vs_out,
    output reg        de_out
);


//These are unused right now
parameter MaxPatternWidth = 8;
parameter MaxPatternHeight = 4;

reg [3:0] hcount;
reg [3:0] vcount;

reg [3:0] hmax;
reg [3:0] vmax;
reg [3:0] hmax2;
reg [3:0] vmax2;

reg [2:0] hindex;
reg [2:0] vindex;
reg [2:0] hindex2;
reg [2:0] vindex2;

reg mask_2x;
reg mask_rotate;
reg mask_enable;

always @(posedge clk) begin

    reg old_hs, old_vs;
    old_hs <= hs_in;
    old_vs <= vs_in;
    hcount <= hcount + 4'b1;

    // hcount and vcount counts pixel rows and columns
    // hindex and vindex half the value of the counters for double size patterns
    // hindex2, vindex2 swap the h and v counters for drawing rotated masks
    hindex <= mask_2x ? hcount[3:1] : hcount[2:0];
    vindex <= mask_2x ? vcount[3:1] : vcount[2:0];
    hindex2 <= mask_rotate ? vindex : hindex;
    vindex2 <= mask_rotate ? hindex : vindex;

    // hmax and vmax store these sizes
    // hmax2 and vmax2 swap the values to handle rotation
    hmax2 <= mask_rotate ? ( vmax << mask_2x ) : ( hmax << mask_2x );
    vmax2 <= mask_rotate ? ( hmax << mask_2x ) : ( vmax << mask_2x );

    if((old_vs && ~vs_in)) vcount <= 4'b0;
    if(old_hs && ~hs_in) begin
        vcount <= vcount + 4'b1;
        hcount <= 4'b0;
        if (vcount == (vmax2 + mask_2x)) vcount <= 4'b0;
        end

    if (hcount == (hmax2 + mask_2x)) hcount <= 4'b0;
end

wire [7:0] r,g,b;
assign {r,g,b} = din;

reg [23:0] d;

// Each element of mask_lut is 3 bits. 1 each for R,G,B
// Red   is   100 = 4
// Green is   010 = 2
// Blue  is   001 = 1
// Magenta is 101 = 5
// Gray is    000 = 0
// White is   111 = 7
// Yellow is  110 = 6
// Cyan is    011 = 3

// So the Pattern
// r,r,g,g,b,b
// r,r,g,g,b,b
// g,b,b,r,r,g
// g,b,b,r,r,g
//
// is
// 4,4,2,2,1,1,5,3
// 4,4,2,2,1,1,0,0,
// 2,1,1,4,4,2,0,0
// 2,1,1,4,4,2,0,0
//
// note that all rows are padded to 8 numbers although every pattern is 6 pixels wide
// The last two entries of the top row "5,3" are the size of the mask. In this case
// "5,3," means this pattern is 6x4 pixels.


reg [2:0] mask_lut[64];

always @(posedge clk) begin

    reg rbit, gbit, bbit;
    reg [23:0] dout1, dout2;
    reg de1,de2,vs1,vs2,hs1,hs2;
    reg [8:0] r2, g2, b2; //9 bits to handle overflow when we add to bright colors.
    reg [7:0] r3, g3, b3; //These are the final colors.

    {rbit,gbit, bbit} = mask_lut[{vindex2[2:0],hindex2[2:0]}];

    // I add 12.5% of the Color value and then subrtact 50% if the mask should be dark
    r2 <= r + {3'b0, r[7:3]} - (rbit ?  9'b0 : {2'b0, r[7:1]});
    g2 <= g + {3'b0, g[7:3]} - (gbit ?  9'b0 : {2'b0, g[7:1]});
    b2 <= b + {3'b0, b[7:3]} - (bbit ?  9'b0 : {2'b0, b[7:1]});

    // Because a pixel can be brighter than 255 we have to clamp the value to 255.
    r3 <= r2[8] ? 8'd255 : r2[7:0];
    g3 <= g2[8] ? 8'd255 : g2[7:0];
    b3 <= b2[8] ? 8'd255 : b2[7:0];

    // I don't know how to keep the color aligned with the sync to avoid a shift.
    // This code is left over from the original hdmi scanlines code.
    dout <= ~mask_enable ? {r,g,b} : {r3 ,g3, b3};
    vs_out <= mask_enable ? vs2 : vs_in;   vs2   <= vs1;   vs1   <= vs_in;
    hs_out <= mask_enable ? hs2 : hs_in;   hs2   <= hs1;   hs1   <= hs_in;
    de_out <= mask_enable ? de2 : de_in;   de2   <= de1;   de1   <= de_in;
end

// 000_000_000_000_000_
always @(posedge clk_sys) begin
    if (cmd_wr) begin
        case(cmd_in[15:13])
        3'b000: {mask_rotate, mask_2x, mask_enable} <= cmd_in[2:0];
        3'b001: vmax <= cmd_in[3:0];
        3'b010: hmax <= cmd_in[3:0];
        3'b011: mask_lut[cmd_in[9:4]] <= cmd_in[2:0];
        endcase
    end
end

endmodule
