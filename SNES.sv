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
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
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

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

//`define DEBUG_BUILD

assign ADC_BUS  = 'Z;

assign AUDIO_S   = 1;
assign AUDIO_MIX = status[20:19];

assign LED_USER  = cart_download | spc_download | (status[23] & bk_pending);
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = osd_btn;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

wire [1:0] ar       = status[33:32];
wire       vcrop_en = status[39];
wire [3:0] vcopt    = status[38:35];
reg        en216p;
reg  [4:0] voff;
always @(posedge CLK_VIDEO) begin
	en216p <= ((HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080) && !forced_scandoubler && !scale);
	voff <= (vcopt < 6) ? {vcopt,1'b0} : ({vcopt,1'b0} - 5'd24);
end

wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? 12'd64 : (ar - 1'd1)),
	.ARY((!ar) ? 12'd49 : 12'd0),
	.CROP_SIZE((en216p & vcrop_en) ? 10'd216 : 10'd0),
	.CROP_OFF(voff),
	.SCALE(status[41:40])
);

///////////////////////  CLOCK/RESET  ///////////////////////////////////

wire clock_locked;
wire clk_mem;
wire clk_sys;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_mem),
	.outclk_1(CLK_VIDEO),
	.outclk_2(clk_sys),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.locked(clock_locked)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

always @(posedge CLK_50M) begin
	reg pald = 0, pald2 = 0;
	reg [2:0] state = 0;

	pald  <= PAL;
	pald2 <= pald;

	cfg_write <= 0;
	if(pald2 != pald) state <= 1;

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
			3: begin
					cfg_address <= 7;
					cfg_data <= pald2 ? 2201376898 : 2537930535;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end

wire reset = RESET | buttons[1] | status[0] | cart_download | spc_download | bk_loading | clearing_ram | msu_data_download;

////////////////////////////  HPS I/O  //////////////////////////////////

// Status Bit Map:
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  XXXXXXXXXXXXXXX

`include "build_id.v"
parameter CONF_STR = {
	"SNES;UART31250,MIDI;",
	"FS0,SFCSMCBINBS ;",
	"FS1,SPC;",
	"-;",
	"OEF,Video Region,Auto,NTSC,PAL;",
	"O13,ROM Header,Auto,No Header,LoROM,HiROM,ExHiROM;",
	"-;",
	"C,Cheats;",
	"H2OO,Cheats Enabled,Yes,No;",
	"-;",
	"D0RC,Load Backup RAM;",
	"D0RD,Save Backup RAM;",
	"D0ON,Autosave,Off,On;",
	"D0-;",

	"P1,Audio & Video;",
	"P1-;",
	"P1o01,Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O9B,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1-;",
	"d5P1o7,Vertical Crop,Disabled,216p(5x);",
	"d5P1o36,Crop Offset,0,2,4,8,10,12,-12,-10,-8,-6,-4,-2;",
	"P1o89,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1oA,Force 256px,Off,On;",
	"P1-;",
	"P1OG,Pseudo Transparency,Blend,Off;",
	"P1-;",
	"P1OJK,Stereo Mix,None,25%,50%,100%;", 

	"P2,Input Options;",
	"P2-;",
	"P2O7,Swap Joysticks,No,Yes;",
	"P2O8,SNAC,No,Yes;",
	"P2-;",
	"P2oB,Miracle Piano,No,Yes;",
	"P2OH,Multitap,Disabled,Port2;",
	"P2O56,Mouse,None,Port1,Port2;",
	"P2-;",
	"P2OPQ,Super Scope,Disabled,Joy1,Joy2,Mouse;",
	"D4P2OR,Super Scope Btn,Joy,Mouse;",
	"D4P2OST,Cross,Small,Big,None;",
	"D4P2o2,Gun Type,Super Scope,Justifier;",
	
	"P3,Hardware;",
	"P3-;",
	"D1P3OI,SuperFX Speed,Normal,Turbo;",
	"D1P3oE,SuperFX FastROM,Yes,No;",
	"D3P3O4,CPU Speed,Normal,Turbo;",
	"P3-;",
	"P3OLM,Initial WRAM,9966(SNES2),00FF(SNES1),55(SD2SNES),FF;",
	"P3oCD,Initial ARAM,9966(SNES2),00FF(SNES1),55(SD2SNES),FF;",

	"-;",
	"R0,Reset;",
	"J1,A(SS Fire),B(SS Cursor),X(SS TurboSw),Y(SS Pause),LT(SS Cursor),RT(SS Fire),Select,Start;",
	"V,v",`BUILD_DATE
};

wire  [1:0] buttons;
wire [63:0] status;
wire [15:0] status_menumask = {en216p, !GUN_MODE, ~turbo_allow, ~gg_available, ~GSU_ACTIVE, ~bk_ena};
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
wire  [7:0] ioctl_index;

wire [11:0] joy0,joy1,joy2,joy3,joy4;
wire [24:0] ps2_mouse;
wire [10:0] ps2_key;

wire  [7:0] joy0_x,joy0_y,joy1_x,joy1_y;

wire [64:0] RTC;

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(new_vmode),

	.joystick_l_analog_0({joy0_y, joy0_x}),
	.joystick_l_analog_1({joy1_y, joy1_x}),
	.joystick_0(joy0),
	.joystick_1(joy1),
	.joystick_2(joy2),
	.joystick_3(joy3),
	.joystick_4(joy4),
	.ps2_mouse(ps2_mouse),
	.ps2_key(ps2_key),

	.status(status),
	.status_menumask(status_menumask),
	.status_in({status[63:5],1'b0,status[3:0]}),
	.status_set(cart_download),

	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),

	.sd_lba('{sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.RTC(RTC),

	.gamma_bus(gamma_bus),
	.EXT_BUS(EXT_BUS)
);

wire       GUN_BTN = status[27];
wire [1:0] GUN_MODE = status[26:25];
wire       GUN_TYPE = status[34];
wire       GSU_TURBO = status[18];
wire       GSU_FASTROM = ~status[46];
wire       BLEND = ~status[16];
wire [1:0] mouse_mode = status[6:5];
wire       joy_swap = status[7] | piano;
wire [2:0] LHRom_type = status[3:1];

wire code_index = &ioctl_index;
wire code_download = ioctl_download & code_index;
wire cart_download = ioctl_download & ioctl_index[5:0] == 0;
wire spc_download = ioctl_download & ioctl_index[5:0] == 6'h01;

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

reg        PAL;
reg  [7:0] rom_type;
reg [23:0] rom_mask, ram_mask;
always @(posedge clk_sys) begin
	reg [3:0] rom_size;
	reg [3:0] ram_size;
	reg       rom_region = 0;

	if (cart_download) begin
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
	else begin
		PAL <= (!status[15:14]) ? rom_region : status[15];
	end
end

reg spc_mode = 0;
always @(posedge clk_sys) begin
	if(ioctl_wr) begin
		spc_mode <= spc_download;
	end
end

reg osd_btn = 0;
always @(posedge clk_sys) begin
	integer timeout = 0;
	reg     has_bootrom = 0;
	reg     last_rst = 0;

	if (RESET) last_rst <= 0;
	if (status[0]) last_rst <= 1;

	if (cart_download & ioctl_wr & status[0]) has_bootrom <= 1;

	if(last_rst & ~status[0]) begin
		osd_btn <= 0;
		if(timeout < 24000000) begin
			timeout <= timeout + 1;
			osd_btn <= ~has_bootrom;
		end
	end
end

////////////////////////////  SYSTEM  ///////////////////////////////////

wire GSU_ACTIVE;
wire turbo_allow;

reg [15:0] main_audio_l;
reg [15:0] main_audio_r;

main main
(
	.RESET_N(RESET_N),

	.MCLK(clk_sys), // 21.47727 / 21.28137
	.ACLK(clk_sys),

	.GSU_ACTIVE(GSU_ACTIVE),
	.GSU_TURBO(GSU_TURBO),
	.GSU_FASTROM(GSU_FASTROM),

	.ROM_TYPE(rom_type),
	.ROM_MASK(rom_mask),
	.RAM_MASK(ram_mask),
	.PAL(PAL),
	.BLEND(BLEND),

	.ROM_ADDR(ROM_ADDR),
	.ROM_D(ROM_D),
	.ROM_Q(ROM_Q),
	.ROM_OE_N(ROM_OE_N),
	.ROM_WE_N(ROM_WE_N),
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

	.R(R_out),
	.G(G_out),
	.B(B_out),

	.FIELD(FIELD),
	.INTERLACE(INTERLACE),
	.HIGH_RES(HIGH_RES),
	.DOTCLK(DOTCLK_out),
	
	.HBLANKn(HBlank_out),
	.VBLANKn(VBlank_out),
	.HSYNC(HSYNC_out),
	.VSYNC(VSYNC_out),

	.JOY1_DI(JOY1_DI),
	.JOY2_DI(GUN_MODE ? LG_DO : JOY2_DI),
	.JOY_STRB(JOY_STRB),
	.JOY1_CLK(JOY1_CLK),
	.JOY2_CLK(JOY2_CLK),
	.JOY1_P6(JOY1_P6),
	.JOY2_P6(JOY2_P6),
	.JOY2_P6_in(JOY2_P6_DI),
	
	.EXT_RTC(RTC),

	.GG_EN(status[24]),
	.GG_CODE(gg_code),
	.GG_RESET((code_download && ioctl_wr && !ioctl_addr) || cart_download),
	.GG_AVAILABLE(gg_available),
	
	.SPC_MODE(spc_mode),

	.IO_ADDR(ioctl_addr[16:0]),
	.IO_DAT(ioctl_dout),
	.IO_WR(spc_download & ioctl_wr),
	
	.TURBO(status[4] & turbo_allow),
	.TURBO_ALLOW(turbo_allow),
	
`ifdef DEBUG_BUILD
	.DBG_BG_EN(DBG_BG_EN),
	.DBG_CPU_EN(DBG_CPU_EN),
`else
	.DBG_BG_EN(5'b11111),
	.DBG_CPU_EN(1'b1),
`endif

	// MSU register handling
	.MSU_TRACK_NUM(msu_track_num),
	.MSU_TRACK_REQUEST(msu_track_request),
	.MSU_TRACK_MOUNTING(msu_track_mounting),
	.MSU_TRACK_MISSING(msu_track_missing),
	.MSU_VOLUME(msu_volume),
	.MSU_AUDIO_REPEAT(msu_audio_repeat),
	.MSU_AUDIO_STOP(msu_audio_stop),
	.MSU_AUDIO_PLAYING(msu_audio_playing),
	.MSU_DATA_ADDR(msu_data_addr),
	.MSU_DATA(msu_data),
	.MSU_DATA_ACK(msu_data_ack),
	.MSU_DATA_SEEK(msu_data_seek),
	.MSU_DATA_REQ(msu_data_req),
	.MSU_ENABLE(msu_enable),

	.AUDIO_L(main_audio_l),
	.AUDIO_R(main_audio_r)
);

assign AUDIO_L = audio_l;
assign AUDIO_R = audio_r;

reg RESET_N = 0;
reg RFSH = 0;
always @(posedge clk_sys) begin
	reg [1:0] div;
	
	div <= div + 1'd1;
	RFSH <= !div;
	
	if (div == 2) RESET_N <= ~reset;
end

////////////////////////////  CODES  ///////////////////////////////////

reg [128:0] gg_code;
wire gg_available;

// Code layout:
// {clock bit, code flags,     32'b address, 32'b compare, 32'b replace}
//  128        127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.

always_ff @(posedge clk_sys) begin
	gg_code[128] <= 0;

	if (code_download & ioctl_wr) begin
		case (ioctl_addr[3:0])
			0:  gg_code[111:96]  <= ioctl_dout; // Flags Bottom Word
			2:  gg_code[127:112] <= ioctl_dout; // Flags Top Word
			4:  gg_code[79:64]   <= ioctl_dout; // Address Bottom Word
			6:  gg_code[95:80]   <= ioctl_dout; // Address Top Word
			8:  gg_code[47:32]   <= ioctl_dout; // Compare Bottom Word
			10: gg_code[63:48]   <= ioctl_dout; // Compare top Word
			12: gg_code[15:0]    <= ioctl_dout; // Replace Bottom Word
			14: begin
				gg_code[31:16]    <= ioctl_dout; // Replace Top Word
				gg_code[128]      <= 1;          // Clock it in
			end
		endcase
	end
end

////////////////////////////  MEMORY  ///////////////////////////////////

reg [16:0] mem_fill_addr;
reg clearing_ram = 0;
always @(posedge clk_sys) begin
	if(~old_downloading & cart_download)
		clearing_ram <= 1'b1;

	if (&mem_fill_addr) clearing_ram <= 0;

	if (clearing_ram)
		mem_fill_addr <= mem_fill_addr + 1'b1;
	else
		mem_fill_addr <= 0;
end

reg [7:0] wram_fill_data;
always @* begin
    case(status[22:21])
        0: wram_fill_data = (mem_fill_addr[8] ^ mem_fill_addr[2]) ? 8'h66 : 8'h99;
        1: wram_fill_data = (mem_fill_addr[9] ^ mem_fill_addr[0]) ? 8'hFF : 8'h00;
        2: wram_fill_data = 8'h55;
        3: wram_fill_data = 8'hFF;
    endcase
end

reg [7:0] aram_fill_data;
always @* begin
    case(status[45:44])
        0: aram_fill_data = (mem_fill_addr[8] ^ mem_fill_addr[2]) ? 8'h66 : 8'h99;
        1: aram_fill_data = (mem_fill_addr[9] ^ mem_fill_addr[0]) ? 8'hFF : 8'h00;
        2: aram_fill_data = 8'h55;
        3: aram_fill_data = 8'hFF;
    endcase
end

wire[23:0] ROM_ADDR;
wire       ROM_OE_N;
wire       ROM_WE_N;
wire       ROM_WORD;
wire[15:0] ROM_D;
wire[15:0] ROM_Q;

wire[24:0] addr_download = ioctl_addr-10'd512;

sdram sdram
(
	.*,
	.init(0), //~clock_locked),
	.clk(clk_mem),
	
	.addr(cart_download ? addr_download : ROM_ADDR),
	.din(cart_download ? ioctl_dout : ROM_D),
	.dout(ROM_Q),
	.rd(~cart_download & (RESET_N ? ~ROM_OE_N : RFSH)),
	.wr(cart_download ? ioctl_wr : ~ROM_WE_N),
	.word(cart_download | ROM_WORD),
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
	.address_b(mem_fill_addr[16:0]),
	.data_b(wram_fill_data),
	.wren_b(clearing_ram)
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
	.address_b(mem_fill_addr[14:0]),
	.wren_b(clearing_ram)
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
	.address_b(mem_fill_addr[14:0]),
	.wren_b(clearing_ram)
);

wire [15:0] ARAM_ADDR;
wire        ARAM_CE_N;
wire        ARAM_WE_N;
wire  [7:0] ARAM_Q, ARAM_D;
dpram_dif #(16,8,15,16) aram
(
	.clock(clk_sys),
	.address_a(ARAM_ADDR),
	.data_a(ARAM_D),
	.wren_a(~ARAM_CE_N & ~ARAM_WE_N),
	.q_A(ARAM_Q),

	// clear the RAM on loading
	.address_b(spc_download ? addr_download[15:1] : mem_fill_addr[15:1]),
	.data_b(spc_download ? ioctl_dout : {2{aram_fill_data}}),
	.wren_b(spc_download ? ioctl_wr : clearing_ram)
);

localparam  BSRAM_BITS = 17; // 1Mbits
wire [19:0] BSRAM_ADDR;
wire        BSRAM_CE_N;
wire        BSRAM_WE_N;
wire  [7:0] BSRAM_Q, BSRAM_D;
dpram_dif #(BSRAM_BITS,8,BSRAM_BITS-1,16) bsram 
(
	.clock(clk_sys),

	//Thrash the BSRAM upon ROM loading
	.address_a(clearing_ram ? mem_fill_addr[BSRAM_BITS-1:0] : BSRAM_ADDR[BSRAM_BITS-1:0]),
	.data_a(clearing_ram ? 8'hFF : BSRAM_D),
	.wren_a(clearing_ram ? 1'b1 : ~BSRAM_CE_N & ~BSRAM_WE_N),
	.q_a(BSRAM_Q),

	.address_b({sd_lba[BSRAM_BITS-10:0],sd_buff_addr}),
	.data_b(sd_buff_dout),
	.wren_b(sd_buff_wr & sd_ack),
	.q_b(sd_buff_din)
);

////////////////////////////  VIDEO  ////////////////////////////////////

wire [7:0] R_out,G_out,B_out;
wire HSYNC_out;
wire VSYNC_out;
wire HBlank_out;
wire VBlank_out;
wire DOTCLK_out;

always @(posedge clk_sys) begin
	DOTCLK <= DOTCLK_out;
	if(DOTCLK ^ DOTCLK_out) begin
		R <= R_out;
		G <= G_out;
		B <= B_out;
		HSYNC  <= HSYNC_out;
		VSYNC  <= VSYNC_out;
		HBlank <= ~HBlank_out;
		VBlank <= ~VBlank_out;
	end
end

reg  [7:0] R,G,B;
wire FIELD,INTERLACE;
reg  HSync, HSYNC;
reg  VSync, VSYNC;
reg  HBlank;
reg  VBlank;
wire HIGH_RES;
reg  DOTCLK;

reg interlace;
reg ce_pix;
always @(posedge CLK_VIDEO) begin
	reg [2:0] pcnt;
	reg old_vsync;
	reg tmp_hres, frame_hres;
	reg old_dotclk;
	
	if(~HBlank & ~VBlank) tmp_hres <= tmp_hres | HIGH_RES;

	old_vsync <= VSync;
	if(~old_vsync & VSync) begin
		frame_hres <= (tmp_hres | ~scandoubler) & ~status[42];
		tmp_hres <= 0;
		interlace <= INTERLACE;
	end

	pcnt <= pcnt + 1'd1;
	old_dotclk <= DOTCLK;
	if(~old_dotclk & DOTCLK & ~HBlank & ~VBlank) pcnt <= 1;

	ce_pix <= !pcnt[1:0] & (frame_hres | ~pcnt[2]);
	
	if(pcnt==3) {HSync, VSync} <= {HSYNC, VSYNC};
end

assign VGA_F1 = interlace & FIELD;
assign VGA_SL = {~interlace,~interlace}&sl[1:0];

wire [2:0] scale = status[11:9];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = ~interlace && (scale || forced_scandoubler);

video_mixer #(.LINE_LENGTH(520), .GAMMA(1)) video_mixer
(
	.*,
	.hq2x(scale==1),
	.freeze_sync(),
	.VGA_DE(vga_de),
	.R((LG_TARGET && GUN_MODE && (!status[29] | LG_T)) ? {8{LG_TARGET[0]}} : R),
	.G((LG_TARGET && GUN_MODE && (!status[29] | LG_T)) ? {8{LG_TARGET[1]}} : G),
	.B((LG_TARGET && GUN_MODE && (!status[29] | LG_T)) ? {8{LG_TARGET[2]}} : B)
);

////////////////////////////  I/O PORTS  ////////////////////////////////

assign {UART_RTS, UART_DTR} = 1;
wire [15:0] uart_data;
wire piano_joypad_do;
wire piano = status[43];
miraclepiano miracle(
	.clk(clk_sys),
	.reset(reset || !piano),
	.strobe(JOY_STRB),
	.joypad_o(piano_joypad_do),
	.joypad_clock(JOY1_CLK),
	.data_o(uart_data),
	.txd(UART_TXD),
	.rxd(UART_RXD)
);
wire [1:0] JOY1_DO = piano ? {1'b1,piano_joypad_do} : JOY1_DO_t;

wire       JOY_STRB;

wire [1:0] JOY1_DO_t;
wire       JOY1_CLK;
wire       JOY1_P6;
ioport port1
(
	.CLK(clk_sys),

	.PORT_LATCH(JOY_STRB),
	.PORT_CLK(JOY1_CLK),
	.PORT_P6(JOY1_P6),
	.PORT_DO(JOY1_DO_t),

	.JOYSTICK1((joy_swap ^ raw_serial) ? joy1 : joy0),

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

	.JOYSTICK1((joy_swap ^ raw_serial) ? joy0 : joy1),
	.JOYSTICK2(joy2),
	.JOYSTICK3(joy3),
	.JOYSTICK4(joy4),

	.MOUSE(ps2_mouse),
	.MOUSE_EN(mouse_mode[1])
);

wire       LG_P6_out;
wire [1:0] LG_DO;
wire [2:0] LG_TARGET;
wire       LG_T = ((GUN_MODE[0]&joy0[6]) | (GUN_MODE[1]&joy1[6])); // always from joysticks

lightgun lightgun
(
	.CLK(clk_sys),
	.RESET(reset),

	.MOUSE(ps2_mouse),
	.MOUSE_XY(&GUN_MODE),

	.JOY_X(GUN_MODE[0] ? joy0_x : joy1_x),
	.JOY_Y(GUN_MODE[0] ? joy0_y : joy1_y),

	.F(GUN_BTN ? ps2_mouse[0] : ((GUN_MODE[0]&(joy0[4]|joy0[9]) | (GUN_MODE[1]&(joy1[4]|joy1[9]))))),
	.C(GUN_BTN ? ps2_mouse[1] : ((GUN_MODE[0]&(joy0[5]|joy0[8]) | (GUN_MODE[1]&(joy1[5]|joy0[8]))))),
	.T(LG_T), // always from joysticks
	.P(ps2_mouse[2] | ((GUN_MODE[0]&joy0[7]) | (GUN_MODE[1]&joy1[7]))), // always from joysticks and mouse

	.HDE(~HBlank),
	.VDE(~VBlank),
	.CLKPIX(DOTCLK),
	
	.TARGET(LG_TARGET),
	.SIZE(status[28]),
	.GUN_TYPE(GUN_TYPE),

	.PORT_LATCH(JOY_STRB),
	.PORT_CLK(JOY2_CLK),
	.PORT_P6(LG_P6_out),
	.PORT_DO(LG_DO)
);

// 1 [oooo|ooo) 7 - 1:+5V  2:Clk  3:Strobe   4:D0  5:D1  6: I/O  7:Gnd

// Indexes:
// IDXDIR   Function    USBPIN
// 0  OUT   Strobe      D+
// 1  OUT   Clk (P1)    D-
// 2  IN    D1          TX-
// 3  OUT   CLK (P2)    GND_d
// 4  BI    I/O         RX+
// 5  IN    P1D0        RX-
// 6  IN    P2D0        TX+

wire raw_serial = status[8];
reg snac_p2 = 0;

assign USER_OUT[2] = 1'b1;
assign USER_OUT[5] = 1'b1;
assign USER_OUT[6] = 1'b1;

wire  [1:0] datajoy0_DI = snac_p2 ? {1'b1, USER_IN[6]} : JOY1_DO;
wire  [1:0] datajoy1_DI = snac_p2 ? {USER_IN[2], USER_IN[6]} : JOY2_DO;

// JOYX_DO[0] is P4, JOYX_DO[1] is P5
wire [1:0] JOY1_DI;
wire [1:0] JOY2_DI;
wire JOY2_P6_DI;

always @(posedge clk_sys) begin
	if (raw_serial) begin
		if (~USER_IN[6])
			snac_p2 <= 1;
	end else begin
		snac_p2 <= 0;
	end
end

always_comb begin
	if (raw_serial) begin
		USER_OUT[0] = JOY_STRB;
		USER_OUT[1] = joy_swap ? ~JOY2_CLK : ~JOY1_CLK;
		USER_OUT[3] = joy_swap ? ~JOY1_CLK : ~JOY2_CLK;
		USER_OUT[4] = joy_swap ? JOY2_P6 : snac_p2 ? JOY2_P6 : JOY1_P6;
		JOY1_DI = joy_swap ? datajoy0_DI : snac_p2 ? {1'b1, USER_IN[5]} : {USER_IN[2], USER_IN[5]};
		JOY2_DI = joy_swap ? {USER_IN[2], USER_IN[5]} : datajoy1_DI;		
		JOY2_P6_DI = joy_swap ? USER_IN[4] : snac_p2 ? USER_IN[4] : (LG_P6_out | !GUN_MODE);
	end else begin
		USER_OUT[0] = 1'b1;
		USER_OUT[1] = 1'b1;
		USER_OUT[3] = 1'b1;
		USER_OUT[4] = 1'b1;
		JOY1_DI = JOY1_DO;
		JOY2_DI = JOY2_DO;
		JOY2_P6_DI = (LG_P6_out | !GUN_MODE);
	end
end

/////////////////////////  STATE SAVE/LOAD  /////////////////////////////

wire bk_save_write = ~BSRAM_CE_N & ~BSRAM_WE_N;
reg bk_pending;

always @(posedge clk_sys) begin
	if (bk_ena && ~OSD_STATUS && bk_save_write)
		bk_pending <= 1'b1;
	else if (bk_state | ~bk_ena)
		bk_pending <= 1'b0;
end

reg bk_ena = 0;
reg old_downloading = 0;
always @(posedge clk_sys) begin
	old_downloading <= cart_download;
	if(~old_downloading & cart_download) bk_ena <= 0;

	//Save file always mounted in the end of downloading state.
	if(cart_download && img_mounted && !img_readonly) bk_ena <= |ram_mask;
end

wire bk_load    = status[12];
wire bk_save    = status[13] | (bk_pending & OSD_STATUS && status[23]);
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
		if(old_downloading & ~cart_download & |img_size & bk_ena) begin
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

//debug
`ifdef DEBUG_BUILD
reg [4:0] DBG_BG_EN = '1;
reg       DBG_CPU_EN = 1;

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];

always @(posedge clk_sys) begin
	reg old_state = 0;

	old_state <= ps2_key[10];

	if((ps2_key[10] != old_state) && pressed) begin
		casex(code)
			'h005: begin DBG_BG_EN[0] <= ~DBG_BG_EN[0]; end // F1
			'h006: begin DBG_BG_EN[1] <= ~DBG_BG_EN[1]; end // F2
			'h004: begin DBG_BG_EN[2] <= ~DBG_BG_EN[2]; end // F3
			'h00C: begin DBG_BG_EN[3] <= ~DBG_BG_EN[3]; end // F4
			'h003: begin DBG_BG_EN[4] <= ~DBG_BG_EN[4]; end // F5
			'h177: begin DBG_CPU_EN   <= ~DBG_CPU_EN;   end // Pause
		endcase
	end
end
`endif

///////////////////////////  MSU1  ///////////////////////////////////

wire msu_enable;
wire msu_audio_download = ioctl_download & ioctl_index[5:0] == 6'h02;
wire msu_data_download  = ioctl_download & ioctl_index[5:0] == 6'h03;

// EXT bus is used to communicate with the HPS for MSU functionality
wire [35:0] EXT_BUS;
hps_ext hps_ext
(
	.reset(reset),
	.clk_sys(clk_sys),
	.EXT_BUS(EXT_BUS),

	.msu_enable(msu_enable),

	.msu_track_mounting(msu_track_mounting),
	.msu_track_missing(msu_track_missing),
	.msu_track_num(msu_track_num),
	.msu_track_request(msu_track_request),

	.msu_audio_size(msu_audio_size),
	.msu_audio_ack(msu_audio_ack),
	.msu_audio_req(msu_audio_req),
	.msu_audio_seek(msu_audio_seek),
	.msu_audio_sector(msu_audio_sector),
	.msu_audio_download(msu_audio_download),

	.msu_data_base(msu_data_base)
);

wire        msu_track_mounting;
wire        msu_track_missing;
wire [15:0] msu_track_num;
wire        msu_track_request;
wire [31:0] msu_audio_size;

wire  [7:0] msu_volume;
wire        msu_audio_repeat;
wire        msu_audio_playing;
wire        msu_audio_stop;

wire        msu_audio_ack;
wire        msu_audio_req;
wire        msu_audio_seek;
wire [21:0] msu_audio_sector;

wire [15:0] msu_l;
wire [15:0] msu_r;

msu_audio msu_audio
(
	.reset(reset),

	.clk(clk_sys),
	.clk_rate(PAL ? 21281370 : 21477270),

	.ctl_volume(msu_volume),
	.ctl_stop(msu_audio_stop),
	.ctl_play(msu_audio_playing),
	.ctl_repeat(msu_audio_repeat),

	.track_size(msu_audio_size),
	.track_processing(msu_track_missing | msu_track_mounting | msu_track_request),

	.audio_download(msu_audio_download),
	.audio_data(ioctl_dout),
	.audio_data_wr(ioctl_wr),

	.audio_ack(msu_audio_ack),
	.audio_sector(msu_audio_sector),
	.audio_req(msu_audio_req),
	.audio_seek(msu_audio_seek),

	.audio_l(msu_l),
	.audio_r(msu_r)
);

reg [15:0] audio_l, audio_r;

always @(posedge clk_sys) begin
	reg [16:0] mix_l, mix_r;

	mix_l = $signed({main_audio_l[15], main_audio_l}) + $signed({msu_l[15], msu_l});
	mix_r = $signed({main_audio_r[15], main_audio_r}) + $signed({msu_r[15], msu_r});

	audio_l <= (^mix_l[16:15]) ? {mix_l[16], {15{mix_l[15]}}} : mix_l[15:0];
	audio_r <= (^mix_r[16:15]) ? {mix_r[16], {15{mix_r[15]}}} : mix_r[15:0];
end

wire [31:0] msu_data_addr;
wire  [7:0] msu_data;
wire        msu_data_ack;
wire        msu_data_seek;
wire        msu_data_req;
wire [31:0] msu_data_base;

assign DDRAM_CLK = clk_mem;

msu_data_store msu_data_store
(
	.*,
	.rd_next(msu_data_req),
	.rd_seek(msu_data_seek),
	.rd_seek_done(msu_data_ack),
	.rd_addr(msu_data_addr),
	.rd_dout(msu_data),
	.base_addr(msu_data_base)
);

endmodule
