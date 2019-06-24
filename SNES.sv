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
	inout  [45:0] HPS_BUS,

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

	//ADC
	inout   [3:0] ADC_BUS,

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

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign AUDIO_S   = 1;
assign AUDIO_MIX = status[20:19];

assign LED_USER  = cart_download | (status[23] & bk_pending);
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign VIDEO_ARX = status[31:30] == 2 ? 8'd16 : (status[30] ? 8'd8 : 8'd64);
assign VIDEO_ARY = status[31:30] == 2 ? 8'd9  : (status[30] ? 8'd7 : 8'd49);

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

wire reset = RESET | buttons[1] | status[0] | cart_download | bk_loading;

////////////////////////////  HPS I/O  //////////////////////////////////

`include "build_id.v"
parameter CONF_STR = {
    "SNES;;",
    "FS,SFCSMCBIN;",
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
    "OUV,Aspect Ratio,4:3,8:7,16:9;",
    "O9B,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
    "OG,Pseudo Transparency,Blend,Off;",
    "OJK,Stereo Mix,None,25%,50%,100%;", 
    "-;",
    "O56,Mouse,None,Port1,Port2;",
    "O7,Swap Joysticks,No,Yes;",
    "OH,Multitap,Disabled,Port2;",
    "-;",
    "OPQ,Super Scope,Disabled,Joy1,Joy2,Mouse;",
    "D4OR,Super Scope Btn,Joy,Mouse;",
    "D4OST,Cross,Small,Big,None;",
    "-;",
    "D1OI,SuperFX Speed,Normal,Turbo;",
    "D3O4,CPU Speed,Normal,Turbo;",
    "-;",
    "R0,Reset;",
    "J1,A(SS Fire),B(SS Cursor),X(SS TurboSw),Y(SS Pause),LT(SS Cursor),RT(SS Fire),Select,Start;",
    "V,v",`BUILD_DATE
};
// free bits: 8,L,M

wire  [1:0] buttons;
wire [31:0] status;
wire [15:0] status_menumask = {!GUN_MODE, ~turbo_allow, ~gg_available, ~GSU_ACTIVE, ~bk_ena};
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

wire  [7:0] joy0_x,joy0_y,joy1_x,joy1_y;

hps_io #(.STRLEN($size(CONF_STR)>>3), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.conf_str(CONF_STR),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(new_vmode),

	.joystick_analog_0({joy0_y, joy0_x}),
	.joystick_analog_1({joy1_y, joy1_x}),
	.joystick_0(joy0),
	.joystick_1(joy1),
	.joystick_2(joy2),
	.joystick_3(joy3),
	.joystick_4(joy4),
	.ps2_mouse(ps2_mouse),

	.status(status),
	.status_menumask(status_menumask),
	.status_in({status[31:5],1'b0,status[3:0]}),
	.status_set(cart_download),

	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),

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

wire       GUN_BTN = status[27];
wire [1:0] GUN_MODE = status[26:25];
wire       GSU_TURBO = status[18];
wire       BLEND = ~status[16];
wire [1:0] mouse_mode = status[6:5];
wire       joy_swap = status[7];
wire [2:0] LHRom_type = status[3:1];

wire code_index = &ioctl_index;
wire code_download = ioctl_download & code_index;
wire cart_download = ioctl_download & ~code_index;

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

////////////////////////////  SYSTEM  ///////////////////////////////////

wire GSU_ACTIVE;
wire turbo_allow;

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
	
	.HBLANKn(HBlank_n),
	.VBLANKn(VBlank_n),
	.HSYNC(HSYNC),
	.VSYNC(VSYNC),

	.JOY1_DI(JOY1_DO),
	.JOY2_DI(GUN_MODE ? LG_DO : JOY2_DO),
	.JOY_STRB(JOY_STRB),
	.JOY1_CLK(JOY1_CLK),
	.JOY2_CLK(JOY2_CLK),
	.JOY1_P6(JOY1_P6),
	.JOY2_P6(JOY2_P6),
	.JOY2_P6_in(LG_P6_out | !GUN_MODE),

	.GG_EN(status[24]),
	.GG_CODE(gg_code),
	.GG_RESET((code_download && ioctl_wr && !ioctl_addr) || cart_download),
	.GG_AVAILABLE(gg_available),
	
	.TURBO(status[4] & turbo_allow),
	.TURBO_ALLOW(turbo_allow),

	.AUDIO_L(AUDIO_L),
	.AUDIO_R(AUDIO_R)
);

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

wire[23:0] ROM_ADDR;
wire       ROM_CE_N;
wire       ROM_OE_N;
wire       ROM_WORD;
wire[15:0] ROM_Q;

sdram sdram
(
	.*,
	.init(0), //~clock_locked),
	.clk(clk_mem),
	
	.addr(cart_download ? ioctl_addr-10'd512 : ROM_ADDR),
	.din(ioctl_dout),
	.dout(ROM_Q),
	.rd(~cart_download & ~ROM_CE_N & ~ROM_OE_N),
	.wr(ioctl_wr & cart_download),
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
	.address_b(ioctl_addr[16:0]),
	.wren_b(ioctl_wr & cart_download)
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
	.wren_b(ioctl_wr & cart_download)
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
	.wren_b(ioctl_wr & cart_download)
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
	.wren_b(ioctl_wr & cart_download)
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
	.address_a(cart_download ? ioctl_addr[BSRAM_BITS-1:0] : BSRAM_ADDR[BSRAM_BITS-1:0]),
	.data_a(cart_download ? ioctl_addr[7:0] : BSRAM_D),
	.wren_a(cart_download ? ioctl_wr : ~BSRAM_CE_N & ~BSRAM_WE_N),
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
wire HBlank_n;
wire VBlank_n;
wire HIGH_RES;
wire DOTCLK;

reg interlace;
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
		interlace <= INTERLACE;
	end

	pcnt <= pcnt + 1'd1;
	old_dotclk <= DOTCLK;
	if(~old_dotclk & DOTCLK & HBlank_n & VBlank_n) pcnt <= 1;

	ce_pix <= !pcnt[1:0] & (frame_hres | ~pcnt[2]);
	
	if(pcnt==3) {HSync, VSync} <= {HSYNC, VSYNC};
end

assign VGA_F1 = interlace & FIELD;
assign VGA_SL = {~interlace,~interlace}&sl[1:0];

wire [2:0] scale = status[11:9];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = ~interlace && (scale || forced_scandoubler);

video_mixer #(.LINE_LENGTH(520)) video_mixer
(
	.*,

	.clk_sys(CLK_VIDEO),
	.ce_pix_out(CE_PIXEL),

	.scanlines(0),
	.hq2x(scale==1),
	.mono(0),

	.HBlank(~HBlank_n),
	.VBlank(~VBlank_n),
	.R((LG_TARGET && GUN_MODE && (!status[29] | LG_T)) ? {8{LG_TARGET[0]}} : R),
	.G((LG_TARGET && GUN_MODE && (!status[29] | LG_T)) ? {8{LG_TARGET[1]}} : G),
	.B((LG_TARGET && GUN_MODE && (!status[29] | LG_T)) ? {8{LG_TARGET[2]}} : B)
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

	.HDE(HBlank_n),
	.VDE(VBlank_n),
	.CLKPIX(DOTCLK),
	
	.TARGET(LG_TARGET),
	.SIZE(status[28]),

	.PORT_LATCH(JOY_STRB),
	.PORT_CLK(JOY2_CLK),
	.PORT_P6(LG_P6_out),
	.PORT_DO(LG_DO)
);

/////////////////////////  STATE SAVE/LOAD  /////////////////////////////

wire bk_save_write = ~BSRAM_CE_N & ~BSRAM_WE_N;
reg bk_pending;

always @(posedge clk_sys) begin
	if (bk_ena && ~OSD_STATUS && bk_save_write)
		bk_pending <= 1'b1;
	else if (bk_state)
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
 
endmodule
