//============================================================================
//  SNES for MiSTer
//  Copyright (C) 2017-2019 Srg320
//  Copyright (C) 2018-2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================ 

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	input         TAPE_IN,

	// SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..5 - USR1..USR4
	// Set USER_OUT to 1 to read from USER_IN.
	input   [5:0] USER_IN,
	output  [5:0] USER_OUT,

	input         OSD_STATUS
);

assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign AUDIO_S   = 1;
assign AUDIO_MIX = status[20:19];

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign VIDEO_ARX = status[8] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[8] ? 8'd9  : 8'd3;

assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

///////////////////////  CLOCK/RESET  ///////////////////////////////////

wire clock_locked;
wire clk_mem;
wire clk_sys;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_mem),
	.outclk_1(SDRAM_CLK),
	.outclk_2(CLK_VIDEO),
	.outclk_3(clk_sys),
	.locked(clock_locked)
);

wire reset = RESET | buttons[1] | status[0] | ioctl_download | bk_loading;


////////////////////////////  HPS I/O  //////////////////////////////////

`include "build_id.v"
parameter CONF_STR1 = {
	"SNES;;",
	"FS,SFCSMCBIN;",
	"-;",
	"O13,ROM Header,Auto,No Header,LoROM,HiROM,ExHiROM;",
	"-;"
};

parameter CONF_STR2 = {
	"C,Load Backup RAM;"
};

parameter CONF_STR3 = {
	"D,Save Backup RAM;", 
};

parameter CONF_STR4 = {
	";",
};

parameter CONF_STR5 = {
	"I,SuperFX speed,Original,Turbo;",
	"OEF,Video Region,Auto,NTSC,PAL;",
	"O8,Aspect ratio,4:3,16:9;",
	"O9B,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"OG,Pseudo-transparency,Blend,Stripes;",
	"OJK,Stereo mix,none,25%,50%,100%;", 
	"-;",
	"O56,Mouse,None,Port1,Port2;",
	"O7,Swap Joysticks,No,Yes;",
	"OH,Multitap,Disabled,Port2;",
	"-;",
	"R0,Reset;",
	"J1,A,B,X,Y,LT,RT,Select,Start;",
	"V,v",`BUILD_DATE
};

wire  [1:0] buttons;
wire [31:0] status;
wire        forced_scandoubler;
reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire        ioctl_download;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_wr;

wire [11:0] joy0,joy1,joy2,joy3,joy4;
wire [24:0] ps2_mouse;

hps_io #(.STRLEN(($size(CONF_STR1)>>3) + ($size(CONF_STR2)>>3) + ($size(CONF_STR3)>>3) + ($size(CONF_STR4)>>3) + ($size(CONF_STR5)>>3) + 4), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.conf_str({CONF_STR1,bk_ena ? "R" : "+",CONF_STR2,bk_ena ? "R" : "+",CONF_STR3,bk_ena ? "-" : "+",CONF_STR4,GSU_ACTIVE ? "O" : "+",CONF_STR5}),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(new_vmode),

	.joystick_0(joy0),
	.joystick_1(joy1),
	.joystick_2(joy2),
	.joystick_3(joy3),
	.joystick_4(joy4),
	.ps2_mouse(ps2_mouse),

	.status(status),

	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_download(ioctl_download),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size)
);

wire       GSU_TURBO = status[18];
wire       BLEND = ~status[16];
wire       PAL = (!status[15:14]) ? rom_region : status[15];
wire [1:0] mouse_mode = status[6:5];
wire       joy_swap = status[7];
wire [2:0] LHRom_type = status[3:1];

reg new_vmode;
always @(posedge clk_sys) begin
	reg old_pal;
	int to;
	
	if(~reset) begin
		old_pal <= PAL;
		if(old_pal != PAL) to <= 2000000;
	end
	
	if(to) begin
		to <= to - 1;
		if(to == 1) new_vmode <= ~new_vmode;
	end
end

//////////////////////////  ROM DETECT  /////////////////////////////////

reg        rom_region = 0;
reg  [7:0] rom_type;
reg [23:0] rom_mask, ram_mask;
always @(posedge clk_sys) begin
	reg [3:0] rom_size;
	reg [3:0] ram_size;

	if(ioctl_wr) begin
		if (ioctl_addr == 0) begin
			rom_size <= 4'hC;
			ram_size <= 4'h0;
			if(!LHRom_type && ioctl_dout[7:0]) {ram_size,rom_size} <= ioctl_dout[7:0];

			case(LHRom_type)
				1: rom_type <= 0;
				2: rom_type <= 0;
				3: rom_type <= 1;
				4: rom_type <= 2;
				default: rom_type <= ioctl_dout[15:8];
			endcase
		end

		if (ioctl_addr == 2) begin
			rom_region <= ioctl_dout[8];
		end

		if(LHRom_type == 2) begin
			if(ioctl_addr == ('h7FD6+'h200)) rom_size <= ioctl_dout[11:8];
			if(ioctl_addr == ('h7FD8+'h200)) ram_size <= ioctl_dout[3:0];
		end
		else if(LHRom_type == 3) begin
			if(ioctl_addr == ('hFFD6+'h200)) rom_size <= ioctl_dout[11:8];
			if(ioctl_addr == ('hFFD8+'h200)) ram_size <= ioctl_dout[3:0];
		end
		else if(LHRom_type == 4) begin
			if(ioctl_addr == ('h40FFD6+'h200)) rom_size <= ioctl_dout[11:8];
			if(ioctl_addr == ('h40FFD8+'h200)) ram_size <= ioctl_dout[3:0];
		end

		rom_mask <= (24'd1024 << rom_size) - 1'd1;
		ram_mask <= ram_size ? (24'd1024 << ram_size) - 1'd1 : 24'd0;
	end
end

////////////////////////////  SYSTEM  ///////////////////////////////////

wire GSU_ACTIVE;

main main
(
	.RESET_N(~reset),

	.MCLK(clk_sys), // 21.47727 / 21.28137
	.ACLK(clk_sys),

	.GSU_ACTIVE(GSU_ACTIVE),
	.GSU_TURBO(GSU_TURBO),

	.ROM_TYPE(rom_type),
	.ROM_MASK(rom_mask),
	.RAM_MASK(ram_mask),
	.PAL(PAL),
	.BLEND(BLEND),

	.ROM_ADDR(ROM_ADDR),
	.ROM_Q(ROM_Q),
	.ROM_CE_N(ROM_CE_N),
	.ROM_OE_N(ROM_OE_N),
	.ROM_WORD(ROM_WORD),

	.BSRAM_ADDR(BSRAM_ADDR),
	.BSRAM_D(BSRAM_D),			
	.BSRAM_Q(BSRAM_Q),			
	.BSRAM_CE_N(BSRAM_CE_N),
	.BSRAM_WE_N(BSRAM_WE_N),

	.WRAM_ADDR(WRAM_ADDR),
	.WRAM_D(WRAM_D),
	.WRAM_Q(WRAM_Q),
	.WRAM_CE_N(WRAM_CE_N),
	.WRAM_WE_N(WRAM_WE_N),

	.VRAM1_ADDR(VRAM1_ADDR),
	.VRAM1_DI(VRAM1_Q),
	.VRAM1_DO(VRAM1_D),
	.VRAM1_WE_N(VRAM1_WE_N),

	.VRAM2_ADDR(VRAM2_ADDR),
	.VRAM2_DI(VRAM2_Q),
	.VRAM2_DO(VRAM2_D),
	.VRAM2_WE_N(VRAM2_WE_N),

	.ARAM_ADDR(ARAM_ADDR),
	.ARAM_D(ARAM_D),
	.ARAM_Q(ARAM_Q),
	.ARAM_CE_N(ARAM_CE_N),
	.ARAM_WE_N(ARAM_WE_N),

	.R(R),
	.G(G),
	.B(B),

	.FIELD(FIELD),
	.INTERLACE(INTERLACE),
	.HIGH_RES(HIGH_RES),
	.DOTCLK(DOTCLK),
	
	.HBLANK(HBlank),
	.VBLANK(VBlank),
	.HSYNC(HSYNC),
	.VSYNC(VSYNC),

	.JOY1_DI(JOY1_DO),
	.JOY2_DI(JOY2_DO),
	.JOY_STRB(JOY_STRB),
	.JOY1_CLK(JOY1_CLK),
	.JOY2_CLK(JOY2_CLK),
	.JOY1_P6(JOY1_P6),
	.JOY2_P6(JOY2_P6),
	
	.AUDIO_L(AUDIO_L),
	.AUDIO_R(AUDIO_R)
);

////////////////////////////  MEMORY  ///////////////////////////////////

wire[22:0] ROM_ADDR;
wire       ROM_CE_N;
wire       ROM_OE_N;
wire       ROM_WORD;
wire[15:0] ROM_Q;

sdram sdram
(
	.*,
	.init(~clock_locked),
	.clk(clk_mem),
	
	.refresh(0),
	.addr(ioctl_download ? ioctl_addr-10'd512 : ROM_ADDR),
	.din(ioctl_dout),
	.dout(ROM_Q),
	.rd(~ioctl_download & ~ROM_CE_N & ~ROM_OE_N),
	.wr(ioctl_wr),
	.word(ioctl_download | ROM_WORD),
	.busy()
);

wire[16:0] WRAM_ADDR;
wire       WRAM_CE_N;
wire       WRAM_WE_N;
wire [7:0] WRAM_Q, WRAM_D;
dpram #(17)	wram
(
	.clock(clk_sys),
	.address_a(WRAM_ADDR),
	.data_a(WRAM_D),
	.wren_a(~WRAM_CE_N & ~WRAM_WE_N),
	.q_a(WRAM_Q),

	// clear the RAM on loading
	.address_b(ioctl_addr[16:0]),
	.wren_b(ioctl_wr)
);

wire [15:0] VRAM1_ADDR;
wire        VRAM1_WE_N;
wire  [7:0] VRAM1_D, VRAM1_Q;
dpram #(15)	vram1
(
	.clock(clk_sys),
	.address_a(VRAM1_ADDR[14:0]),
	.data_a(VRAM1_D),
	.wren_a(~VRAM1_WE_N),
	.q_a(VRAM1_Q),

	// clear the RAM on loading
	.address_b(ioctl_addr[14:0]),
	.wren_b(ioctl_wr)
);

wire [15:0] VRAM2_ADDR;
wire        VRAM2_WE_N;
wire  [7:0] VRAM2_D, VRAM2_Q;
dpram #(15) vram2
(
	.clock(clk_sys),
	.address_a(VRAM2_ADDR[14:0]),
	.data_a(VRAM2_D),
	.wren_a(~VRAM2_WE_N),
	.q_a(VRAM2_Q),

	// clear the RAM on loading
	.address_b(ioctl_addr[14:0]),
	.wren_b(ioctl_wr)
);

wire [15:0] ARAM_ADDR;
wire        ARAM_CE_N;
wire        ARAM_WE_N;
wire  [7:0] ARAM_Q, ARAM_D;
dpram #(16) aram
(
	.clock(clk_sys),
	.address_a(ARAM_ADDR),
	.data_a(ARAM_D),
	.wren_a(~ARAM_CE_N & ~ARAM_WE_N),
	.q_A(ARAM_Q),

	// clear the RAM on loading
	.address_b(ioctl_addr[15:0]),
	.wren_b(ioctl_wr)
);

localparam  BSRAM_BITS = 16; // 512Kbits is largest known size in official carts
wire [19:0] BSRAM_ADDR;
wire        BSRAM_CE_N;
wire        BSRAM_WE_N;
wire  [7:0] BSRAM_Q, BSRAM_D;
dpram_dif #(BSRAM_BITS,8,BSRAM_BITS-1,16) bsram 
(
	.clock(clk_sys),

	//Clear BSRAM upon ROM loading
	.address_a(ioctl_download ? ioctl_addr[BSRAM_BITS-1:0] : BSRAM_ADDR[BSRAM_BITS-1:0]),
	.data_a(ioctl_download ? 8'h00 : BSRAM_D),
	.wren_a(ioctl_download ? ioctl_wr : ~BSRAM_CE_N & ~BSRAM_WE_N),
	.q_a(BSRAM_Q),

	.address_b({sd_lba[BSRAM_BITS-10:0],sd_buff_addr}),
	.data_b(sd_buff_dout),
	.wren_b(sd_buff_wr & sd_ack),
	.q_b(sd_buff_din)
);

////////////////////////////  VIDEO  ////////////////////////////////////

wire [7:0] R,G,B;
wire FIELD,INTERLACE;
wire HSync, HSYNC;
wire VSync, VSYNC;
wire HBlank;
wire VBlank;
wire HIGH_RES;
wire DOTCLK;

reg ce_pix;
always @(posedge CLK_VIDEO) begin
	reg [2:0] pcnt;
	reg old_vsync;
	reg tmp_hres, frame_hres;
	reg old_dotclk;
	
	tmp_hres <= tmp_hres | HIGH_RES;

	old_vsync <= VSync;
	if(~old_vsync & VSync) begin
		frame_hres <= tmp_hres | ~scandoubler;
		tmp_hres <= HIGH_RES;
	end

	pcnt <= pcnt + 1'd1;
	old_dotclk <= DOTCLK;
	if(~old_dotclk & DOTCLK & ~HBlank & ~VBlank) pcnt <= 1;

	ce_pix <= !pcnt[1:0] & (frame_hres | ~pcnt[2]);
	
	if(pcnt==3) {HSync, VSync} <= {HSYNC, VSYNC};
end

assign VGA_F1 = INTERLACE & FIELD;
assign VGA_SL = {~INTERLACE,~INTERLACE}&sl[1:0];

wire [2:0] scale = status[11:9];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = ~INTERLACE && (scale || forced_scandoubler);

video_mixer #(.LINE_LENGTH(520)) video_mixer
(
	.*,

	.clk_sys(CLK_VIDEO),
	.ce_pix_out(CE_PIXEL),

	.scanlines(0),
	.hq2x(scale==1),
	.mono(0),

	.R(R),
	.G(G),
	.B(B)
);

////////////////////////////  I/O PORTS  ////////////////////////////////

wire       JOY_STRB;

wire [1:0] JOY1_DO;
wire       JOY1_CLK;
wire       JOY1_P6;
ioport port1
(
	.CLK(clk_sys),

	.PORT_LATCH(JOY_STRB),
	.PORT_CLK(JOY1_CLK),
	.PORT_P6(JOY1_P6),
	.PORT_DO(JOY1_DO),

	.JOYSTICK1(joy_swap ? joy1 : joy0),

	.MOUSE(ps2_mouse),
	.MOUSE_EN(mouse_mode[0])
);

wire [1:0] JOY2_DO;
wire       JOY2_CLK;
wire       JOY2_P6;
ioport port2
(
	.CLK(clk_sys),

	.MULTITAP(status[17]),

	.PORT_LATCH(JOY_STRB),
	.PORT_CLK(JOY2_CLK),
	.PORT_P6(JOY2_P6),
	.PORT_DO(JOY2_DO),

	.JOYSTICK1(joy_swap ? joy0 : joy1),
	.JOYSTICK2(joy2),
	.JOYSTICK3(joy3),
	.JOYSTICK4(joy4),

	.MOUSE(ps2_mouse),
	.MOUSE_EN(mouse_mode[1])
);


/////////////////////////  STATE SAVE/LOAD  /////////////////////////////

reg bk_ena = 0;
reg old_downloading = 0;
always @(posedge clk_sys) begin
	old_downloading <= ioctl_download;
	if(~old_downloading & ioctl_download) bk_ena <= 0;
	
	//Save file always mounted in the end of downloading state.
	if(ioctl_download && img_mounted && img_size && !img_readonly) bk_ena <= |ram_mask;
end

wire bk_load    = status[12];
wire bk_save    = status[13];
reg  bk_loading = 0;
reg  bk_state   = 0;

always @(posedge clk_sys) begin
	reg old_load = 0, old_save = 0, old_ack;

	old_load <= bk_load & bk_ena;
	old_save <= bk_save & bk_ena;
	old_ack  <= sd_ack;

	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;
	
	if(!bk_state) begin
		if((~old_load & bk_load) | (~old_save & bk_save)) begin
			bk_state <= 1;
			bk_loading <= bk_load;
			sd_lba <= 0;
			sd_rd <=  bk_load;
			sd_wr <= ~bk_load;
		end
		if(old_downloading & ~ioctl_download & bk_ena) begin
			bk_state <= 1;
			bk_loading <= 1;
			sd_lba <= 0;
			sd_rd <= 1;
			sd_wr <= 0;
		end
	end else begin
		if(old_ack & ~sd_ack) begin
			if(sd_lba >= ram_mask[23:9]) begin
				bk_loading <= 0;
				bk_state <= 0;
			end else begin
				sd_lba <= sd_lba + 1'd1;
				sd_rd  <=  bk_loading;
				sd_wr  <= ~bk_loading;
			end
		end
	end
end
 
endmodule
