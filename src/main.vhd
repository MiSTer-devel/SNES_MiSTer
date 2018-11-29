library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity main is
	port(
		MCLK_50M		: in  std_logic;
		RESET_N		: in  std_logic;

		CLK_21M		: in  std_logic;
		CLK_24M		: in  std_logic;

		ROM_TYPE		: in  std_logic_vector(7 downto 0);
		ROM_MASK		: in  std_logic_vector(23 downto 0);
		RAM_MASK		: in  std_logic_vector(23 downto 0);

		ROM_ADDR		: out std_logic_vector(22 downto 0);
		ROM_Q			: in  std_logic_vector(7 downto 0);
		ROM_CE_N		: out std_logic;
		ROM_OE_N		: out std_logic;

		BSRAM_ADDR	: out std_logic_vector(19 downto 0);
		BSRAM_D		: out std_logic_vector(7 downto 0);
		BSRAM_Q		: in  std_logic_vector(7 downto 0);
		BSRAM_CE_N	: out std_logic;
		BSRAM_OE_N	: out std_logic;
		BSRAM_WE_N	: out std_logic;

		WSRAM_ADDR	: out std_logic_vector(16 downto 0);
		WSRAM_D		: out std_logic_vector(7 downto 0);
		WSRAM_Q		: in  std_logic_vector(7 downto 0);
		WSRAM_CE_N	: out std_logic;
		WSRAM_OE_N	: out std_logic;
		WSRAM_WE_N	: out std_logic;

		VSRAM_ADDRA	: out std_logic_vector(15 downto 0);
		VSRAM_DAI	: in  std_logic_vector(7 downto 0);
		VSRAM_DAO	: out std_logic_vector(7 downto 0);
		VSRAM_WEA_N	: out std_logic;
		VSRAM_ADDRB	: out std_logic_vector(15 downto 0);
		VSRAM_DBI	: in  std_logic_vector(7 downto 0);
		VSRAM_DBO	: out std_logic_vector(7 downto 0);
		VSRAM_WEB_N	: out std_logic;
		VSRAM_OE_N	: out std_logic;

		ASRAM_ADDR	: out std_logic_vector(15 downto 0);
		ASRAM_D		: out std_logic_vector(7 downto 0);
		ASRAM_Q		: in  std_logic_vector(7 downto 0);
		ASRAM_CE_N	: out std_logic;
		ASRAM_OE_N	: out std_logic;
		ASRAM_WE_N	: out std_logic;

		CE_PIX		: out std_logic;
		PAL			: in  std_logic;
		R,G,B			: out std_logic_vector(4 downto 0);
		HBLANK		: out std_logic;
		VBLANK		: out std_logic;
		HSYNC			: out std_logic;
		VSYNC			: out std_logic;
		FIELD			: out std_logic;
		INTERLACE	: out std_logic;

		JOY1_DI		: in  std_logic_vector(1 downto 0);
		JOY2_DI		: in  std_logic_vector(1 downto 0);
		JOY_STRB		: out std_logic;
		JOY1_CLK		: out std_logic;
		JOY2_CLK		: out std_logic;

		AUDIO_L		: out std_logic_vector(15 downto 0);
		AUDIO_R		: out std_logic_vector(15 downto 0)
	);
end main;

architecture rtl of main is

	signal CA 		: std_logic_vector(23 downto 0);
	signal CPURD_N	: std_logic;
	signal CPUWR_N	: std_logic;
	signal DI 		: std_logic_vector(7 downto 0);
	signal DO 		: std_logic_vector(7 downto 0);
	signal RAMSEL_N: std_logic;
	signal ROMSEL_N: std_logic;
	signal IRQ_N	: std_logic;
	signal PA 		: std_logic_vector(7 downto 0);
	signal PARD_N 	: std_logic;
	signal PAWR_N 	: std_logic;
	signal SYSCLK 	: std_logic;
	signal REFRESH : std_logic;

	signal HBLANKn	: std_logic;
	signal VBLANKn	: std_logic;

	signal RGB_OUT : std_logic_vector(14 downto 0);

begin

	SNES : entity work.SNES
	port map(
		MCLK			=> CLK_21M,
		DSPCLK		=> CLK_24M,
		
		RST_N			=> RESET_N,
		ENABLE		=> '1',
		PAL			=> PAL,
		
		CA     		=> CA,
		CPURD_N		=> CPURD_N,
		CPUWR_N		=> CPUWR_N,
			
		PA				=> PA,
		PARD_N		=> PARD_N,
		PAWR_N		=> PAWR_N,
		DI				=> DI,
		DO				=> DO,
			
		RAMSEL_N		=> RAMSEL_N,
		ROMSEL_N		=> ROMSEL_N,
			
		SYSCLK		=> SYSCLK,
		REFRESH		=> REFRESH,
			
		IRQ_N			=> IRQ_N,
			
		WSRAM_ADDR	=> WSRAM_ADDR,
		WSRAM_D		=> WSRAM_D,
		WSRAM_Q		=> WSRAM_Q,
		WSRAM_CE_N	=> WSRAM_CE_N,
		WSRAM_OE_N	=> WSRAM_OE_N,
		WSRAM_WE_N	=> WSRAM_WE_N,
			
		VRAM_ADDRA	=> VSRAM_ADDRA,
		VRAM_ADDRB	=> VSRAM_ADDRB,
		VRAM_DAI		=> VSRAM_DAI,
		VRAM_DBI		=> VSRAM_DBI,
		VRAM_DAO		=> VSRAM_DAO,
		VRAM_DBO		=> VSRAM_DBO,
		VRAM_RD_N	=> VSRAM_OE_N,
		VRAM_WRA_N	=> VSRAM_WEA_N,
		VRAM_WRB_N	=> VSRAM_WEB_N,
			
		ARAM_ADDR	=> ASRAM_ADDR,
		ARAM_D		=> ASRAM_D,
		ARAM_Q		=> ASRAM_Q,
		ARAM_CE_N	=> ASRAM_CE_N,
		ARAM_OE_N	=> ASRAM_OE_N,
		ARAM_WE_N	=> ASRAM_WE_N,
			
		JOY1_DI		=> JOY1_DI,
		JOY2_DI		=> JOY2_DI,
		JOY_STRB		=> JOY_STRB,
		JOY1_CLK		=> JOY1_CLK,
		JOY2_CLK		=> JOY2_CLK,
		
		CE_PIX		=> CE_PIX,
		HDE			=> HBLANKn,
		VDE			=> VBLANKn,
			
		RGB_OUT		=> RGB_OUT,
		FIELD_OUT	=> FIELD,
		INTERLACE   => INTERLACE,
		
		HSYNC			=> HSYNC,
		VSYNC			=> VSYNC,
		
		DBG_SEL		=> (others =>'0'),
		DBG_REG		=> (others =>'0'),
		DBG_REG_WR	=> '0',
		DBG_DAT_IN	=> (others =>'0'),
		
		AUDIO_L		=> AUDIO_L,
		AUDIO_R		=> AUDIO_R
	);

	HBLANK <= not HBLANKn;
	VBLANK <= not VBLANKn;

	SMAP : entity work.LHRomMap
	--SMAP : entity work.SDD1Map
	--SMAP : entity work.DSPMap
	--SMAP : entity work.CX4Map
	port map(
		MCLK50		=> MCLK_50M,
		MCLK			=> CLK_21M,
		RST_N			=> RESET_N,
		ENABLE		=> '1',
		
		CA				=> CA,
		DI				=> DO,
		DO				=> DI,
		CPURD_N		=> CPURD_N,
		CPUWR_N		=> CPUWR_N,
		
		PA				=> PA,
		PARD_N		=> PARD_N,
		PAWR_N		=> PAWR_N,
		
		ROMSEL_N		=> ROMSEL_N,
		RAMSEL_N		=> RAMSEL_N,
		
		SYSCLK		=> SYSCLK,
		REFRESH		=> REFRESH,

		IRQ_N			=> IRQ_N,
		
		ROM_ADDR		=> ROM_ADDR,
		ROM_Q			=> ROM_Q,
		ROM_CE_N		=> ROM_CE_N,
		ROM_OE_N		=> ROM_OE_N,

		BSRAM_ADDR	=> BSRAM_ADDR,
		BSRAM_D		=> BSRAM_D,
		BSRAM_Q		=> BSRAM_Q,
		BSRAM_CE_N	=> BSRAM_CE_N,
		BSRAM_OE_N	=> BSRAM_OE_N,
		BSRAM_WE_N	=> BSRAM_WE_N,

		MAP_CTRL		=> ROM_TYPE,
		ROM_MASK		=> ROM_MASK,
		BSRAM_MASK	=> RAM_MASK,
		
		DBG_REG  	=> (others =>'0'),
		DBG_DAT_IN	=> (others =>'0'),
		DBG_DAT_WR	=> '0'
	);

	R <= RGB_OUT(4 downto 0);
	G <= RGB_OUT(9 downto 5);
	B <= RGB_OUT(14 downto 10);
	
end rtl;
