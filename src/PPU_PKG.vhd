library IEEE;
use IEEE.Std_Logic_1164.all;
library STD;
use ieee.numeric_std.all;

package PPU_PKG is  

	constant DOT_NUM: unsigned(8 downto 0) := "101010100"; --340 
	constant LINE_NUM_NTSC: unsigned(8 downto 0) := "100000110"; --262 
	constant LINE_NUM_PAL: unsigned(8 downto 0) := "100111000"; --312 

	constant LINE_VSYNC_NTSC: unsigned(8 downto 0) := "011101100"; --236 
	constant LINE_VSYNC_PAL: unsigned(8 downto 0)  := "100000000"; --256 
	
	constant BG1: integer range 0 to 3 := 0; 
	constant BG2: integer range 0 to 3 := 1; 
	constant BG3: integer range 0 to 3 := 2; 
	constant BG4: integer range 0 to 3 := 3; 
	
	type BgFetch_t is (
		BF_TILEMAP,
		BF_TILEDAT0,
		BF_TILEDAT1,
		BF_TILEDAT2,
		BF_TILEDAT3,
		BF_TILEDATM7,
		BF_OPT0,
		BF_OPT1,
		BF_MODE7
	);
	
	type BgFetch_r is record
		BG			: integer range 0 to 3;
		MODE		: BgFetch_t;
	end record;
	
	type BgFetchTbl_t is array(0 to 7, 0 to 7) of BgFetch_r;
	constant BF_TBL: BgFetchTbl_t := (
	((BG4,BF_TILEMAP),  (BG3,BF_TILEMAP),  (BG2,BF_TILEMAP),  (BG1,BF_TILEMAP),  (BG4,BF_TILEDAT0), (BG3,BF_TILEDAT0), (BG2,BF_TILEDAT0), (BG1,BF_TILEDAT0)),-- MODE 0
	((BG3,BF_TILEMAP),  (BG2,BF_TILEMAP),  (BG1,BF_TILEMAP),  (BG3,BF_TILEDAT0), (BG2,BF_TILEDAT0), (BG2,BF_TILEDAT1), (BG1,BF_TILEDAT0), (BG1,BF_TILEDAT1)),-- MODE 1
	((BG2,BF_TILEMAP),  (BG1,BF_TILEMAP),  (BG3,BF_OPT0),     (BG3,BF_OPT1),     (BG2,BF_TILEDAT0), (BG2,BF_TILEDAT1), (BG1,BF_TILEDAT0), (BG1,BF_TILEDAT1)),-- MODE 2
	((BG2,BF_TILEMAP),  (BG1,BF_TILEMAP),  (BG2,BF_TILEDAT0), (BG2,BF_TILEDAT1), (BG1,BF_TILEDAT0), (BG1,BF_TILEDAT1), (BG1,BF_TILEDAT2), (BG1,BF_TILEDAT3)),-- MODE 3
	((BG2,BF_TILEMAP),  (BG1,BF_TILEMAP),  (BG3,BF_OPT0),     (BG2,BF_TILEDAT0), (BG1,BF_TILEDAT0), (BG1,BF_TILEDAT1), (BG1,BF_TILEDAT2), (BG1,BF_TILEDAT3)),-- MODE 4
	((BG2,BF_TILEMAP),  (BG1,BF_TILEMAP),  (BG2,BF_TILEDAT0), (BG2,BF_TILEDAT1), (BG1,BF_TILEDAT0), (BG1,BF_TILEDAT1), (BG1,BF_TILEDAT2), (BG1,BF_TILEDAT3)),-- MODE 5
	((BG2,BF_TILEMAP),  (BG1,BF_TILEMAP),  (BG3,BF_OPT0),     (BG3,BF_OPT1),     (BG1,BF_TILEDAT0), (BG1,BF_TILEDAT1), (BG1,BF_TILEDAT2), (BG1,BF_TILEDAT3)),-- MODE 6
	((BG1,BF_TILEDATM7),(BG1,BF_TILEDATM7),(BG1,BF_TILEDATM7),(BG1,BF_TILEDATM7),(BG1,BF_TILEDATM7),(BG1,BF_TILEDATM7),(BG1,BF_TILEDATM7),(BG1,BF_TILEDATM7))-- MODE 7
	);
	
	type BgScAddr_t is array(0 to 3) of std_logic_vector(5 downto 0);
	type BgScSize_t is array(0 to 3) of std_logic_vector(1 downto 0);
	type BgTileAddr_t is array(0 to 3) of std_logic_vector(3 downto 0);
	type BgScroll_t is array(0 to 3) of std_logic_vector(9 downto 0);
	type BgData_t is array(0 to 7) of std_logic_vector(15 downto 0);
	type BgTileInfo_t is array(0 to 3) of std_logic_vector(15 downto 0);
	type BgTileAtr_t is array(0 to 3) of std_logic_vector(3 downto 0);
	
	type Sprite_r is record
		X		: unsigned(8 downto 0);
		Y		: unsigned(7 downto 0);
		TILE	: unsigned(7 downto 0);
		N		: std_logic;
		PAL	: std_logic_vector(2 downto 0);
		PRIO	: std_logic_vector(1 downto 0);
		HFLIP	: std_logic;
		VFLIP	: std_logic;
		S		: std_logic;
	end record;
	type RangeOam_t is array(0 to 31) of Sprite_r;
	
	type SprSize_t is array(0 to 15) of unsigned(7 downto 0);
	constant SPR_WIDTH: SprSize_t := (
	x"07", x"07", x"07", x"0F", x"0F", x"1F", x"0F", x"0F",
	x"0F", x"1F", x"3F", x"1F", x"3F", x"3F", x"1F", x"1F"
	);
	constant SPR_HEIGHT: SprSize_t := (
	x"07", x"07", x"07", x"0F", x"0F", x"1F", x"1F", x"1F",
	x"0F", x"1F", x"3F", x"1F", x"3F", x"3F", x"3F", x"1F"
	);
	function SprWidth(size: std_logic_vector(3 downto 0)) return unsigned;
	function SprHeight(size: std_logic_vector(3 downto 0)) return unsigned;
		
	function FlipPlane(bp: std_logic_vector(7 downto 0); flip: std_logic) return std_logic_vector;
	function FlipBGPlaneHR(bp: std_logic_vector(15 downto 0); flip: std_logic; main: std_logic) return std_logic_vector;
									  
	function AddSub(a: unsigned(4 downto 0); b: unsigned(4 downto 0);
						 add: std_logic; half: std_logic) return unsigned;
	function GetDCM(a: std_logic_vector(10 downto 0)) return std_logic_vector;
	function Bright(mb: std_logic_vector(3 downto 0); b: unsigned(4 downto 0)) return std_logic_vector;

end PPU_PKG;

package body PPU_PKG is

	function FlipPlane(bp: std_logic_vector(7 downto 0); flip: std_logic) return std_logic_vector is
		variable res: std_logic_vector(7 downto 0); 
	begin
		if flip = '1' then
			res := bp(0)&bp(1)&bp(2)&bp(3)&bp(4)&bp(5)&bp(6)&bp(7);
		else
			res := bp;
		end if;
		return res;
	end function;
	
	function FlipBGPlaneHR(bp: std_logic_vector(15 downto 0); flip: std_logic; main: std_logic) return std_logic_vector is
		variable res: std_logic_vector(7 downto 0); 
		variable temp: std_logic_vector(15 downto 0); 
	begin
		if flip = '1' then
			temp := bp(0)&bp(1)&bp(2)&bp(3)&bp(4)&bp(5)&bp(6)&bp(7)&bp(8)&bp(9)&bp(10)&bp(11)&bp(12)&bp(13)&bp(14)&bp(15);
		else
			temp := bp;
		end if;
		if main = '1' then
			res := temp(14)&temp(12)&temp(10)&temp(8)&temp(6)&temp(4)&temp(2)&temp(0);
		else
			res := temp(15)&temp(13)&temp(11)&temp(9)&temp(7)&temp(5)&temp(3)&temp(1);
		end if;
		return res;
	end function;
	
	function SprWidth(size: std_logic_vector(3 downto 0)) return unsigned is
		variable temp: unsigned(7 downto 0); 
	begin
		temp := SPR_WIDTH(to_integer(unsigned(size)));
		return temp(5 downto 0);
	end function;
	
	function SprHeight(size: std_logic_vector(3 downto 0)) return unsigned is
		variable temp: unsigned(7 downto 0); 
	begin
		temp := SPR_HEIGHT(to_integer(unsigned(size)));
		return temp(5 downto 0);
	end function;
	
	function AddSub(a: unsigned(4 downto 0); 
						 b: unsigned(4 downto 0);
						 add: std_logic;
						 half: std_logic) return unsigned is
		variable temp: unsigned(5 downto 0); 
		variable res: unsigned(4 downto 0); 
	begin
		if add = '1' then
			temp := resize(a,temp'length) + resize(b,temp'length);
			if half = '1' then
				temp := "0"&temp(5 downto 1);
			elsif temp(5) = '1' then
				temp := "111111";
			end if;
		else
			temp := resize(a,temp'length) - resize(b,temp'length);
			if temp(5) = '1' then
				temp := "000000";
			elsif half = '1' then
				temp := "0"&temp(5 downto 1);
			end if;
		end if;
		
		res := temp(4 downto 0);
		return res;
	end function;

	function GetDCM(a: std_logic_vector(10 downto 0)) return std_logic_vector is
		variable res: std_logic_vector(14 downto 0); 
	begin
		res := a(7 downto 6) & a(10) & "00" & a(5 downto 3) & a(9) & "0" & a(2 downto 0) & a(8) & "0";
		return res;
	end function;

	function Bright(mb: std_logic_vector(3 downto 0); b: unsigned(4 downto 0)) return std_logic_vector is
		variable temp: unsigned(8 downto 0); 
		variable res: std_logic_vector(7 downto 0); 
	begin
		temp := b * unsigned(mb) + resize(b,temp'length);
		if mb = x"0" then
			res := (others => '0');
		else
			res := std_logic_vector(temp(8 downto 1) + temp(8 downto 6));
		end if;
		return res;
	end function;

end package body PPU_PKG;