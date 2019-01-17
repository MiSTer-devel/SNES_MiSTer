library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity main is
	port(
		RESET_N		: in  std_logic;

		MEM_CLK		: in  std_logic;
		MCLK			: in  std_logic;
		ACLK			: in  std_logic;

		REFRESH		: out std_logic;

		ROM_TYPE		: in  std_logic_vector(7 downto 0);
		ROM_MASK		: in  std_logic_vector(23 downto 0);
		RAM_MASK		: in  std_logic_vector(23 downto 0);

		ROM_ADDR		: out std_logic_vector(22 downto 0);
		ROM_Q			: in  std_logic_vector(15 downto 0);
		ROM_CE_N		: out std_logic;
		ROM_OE_N		: out std_logic;
		ROM_WORD		: out std_logic;

		BSRAM_ADDR	: out std_logic_vector(19 downto 0);
		BSRAM_D		: out std_logic_vector(7 downto 0);
		BSRAM_Q		: in  std_logic_vector(7 downto 0);
		BSRAM_CE_N	: out std_logic;
		BSRAM_OE_N	: out std_logic;
		BSRAM_WE_N	: out std_logic;

		WRAM_ADDR	: out std_logic_vector(16 downto 0);
		WRAM_D		: out std_logic_vector(7 downto 0);
		WRAM_Q		: in  std_logic_vector(7 downto 0);
		WRAM_CE_N	: out std_logic;
		WRAM_OE_N	: out std_logic;
		WRAM_WE_N	: out std_logic;

		VRAM1_ADDR	: out std_logic_vector(15 downto 0);
		VRAM1_DI		: in  std_logic_vector(7 downto 0);
		VRAM1_DO		: out std_logic_vector(7 downto 0);
		VRAM1_WE_N	: out std_logic;
		VRAM2_ADDR	: out std_logic_vector(15 downto 0);
		VRAM2_DI		: in  std_logic_vector(7 downto 0);
		VRAM2_DO		: out std_logic_vector(7 downto 0);
		VRAM2_WE_N	: out std_logic;
		VRAM_OE_N	: out std_logic;

		ARAM_ADDR	: out std_logic_vector(15 downto 0);
		ARAM_D		: out std_logic_vector(7 downto 0);
		ARAM_Q		: in  std_logic_vector(7 downto 0);
		ARAM_CE_N	: out std_logic;
		ARAM_OE_N	: out std_logic;
		ARAM_WE_N	: out std_logic;

		BLEND			: in std_logic;
		PAL			: in  std_logic;
		HIGH_RES		: out std_logic;
		FIELD			: out std_logic;
		INTERLACE	: out std_logic;
		DOTCLK		: out std_logic;
		R,G,B			: out std_logic_vector(7 downto 0);
		HBLANK		: out std_logic;
		VBLANK		: out std_logic;
		HSYNC			: out std_logic;
		VSYNC			: out std_logic;

		JOY1_DI		: in  std_logic_vector(1 downto 0);
		JOY2_DI		: in  std_logic_vector(1 downto 0);
		JOY_STRB		: out std_logic;
		JOY1_CLK		: out std_logic;
		JOY2_CLK		: out std_logic;
		JOY1_P6		: out std_logic;
		JOY2_P6		: out std_logic;

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
	signal SYSCLKF_CE	: std_logic;
	signal SYSCLKR_CE	: std_logic;

	signal HBLANKn	: std_logic;
	signal VBLANKn	: std_logic;

	signal RGB_OUT : std_logic_vector(23 downto 0);

	signal DLH_DO				: std_logic_vector(7 downto 0);
	signal DLH_IRQ_N			: std_logic;
	signal DLH_ROM_ADDR		: std_logic_vector(22 downto 0);
	signal DLH_ROM_CE_N		: std_logic;
	signal DLH_ROM_OE_N		: std_logic;
	signal DLH_ROM_WORD		: std_logic;
	signal DLH_BSRAM_ADDR	: std_logic_vector(19 downto 0);
	signal DLH_BSRAM_D		: std_logic_vector(7 downto 0);
	signal DLH_BSRAM_CE_N	: std_logic;
	signal DLH_BSRAM_OE_N	: std_logic;
	signal DLH_BSRAM_WE_N	: std_logic;
	signal DLH_REFRESH		: std_logic;

	signal CX4_DO				: std_logic_vector(7 downto 0);
	signal CX4_IRQ_N			: std_logic;
	signal CX4_ROM_ADDR		: std_logic_vector(22 downto 0);
	signal CX4_ROM_CE_N		: std_logic;
	signal CX4_ROM_OE_N		: std_logic;
	signal CX4_ROM_WORD		: std_logic;
	signal CX4_BSRAM_ADDR	: std_logic_vector(19 downto 0);
	signal CX4_BSRAM_D		: std_logic_vector(7 downto 0);
	signal CX4_BSRAM_CE_N	: std_logic;
	signal CX4_BSRAM_OE_N	: std_logic;
	signal CX4_BSRAM_WE_N	: std_logic;
	signal CX4_REFRESH		: std_logic;

	signal SDD_DO				: std_logic_vector(7 downto 0);
	signal SDD_IRQ_N			: std_logic;
	signal SDD_ROM_ADDR		: std_logic_vector(22 downto 0);
	signal SDD_ROM_CE_N		: std_logic;
	signal SDD_ROM_OE_N		: std_logic;
	signal SDD_ROM_WORD		: std_logic;
	signal SDD_BSRAM_ADDR	: std_logic_vector(19 downto 0);
	signal SDD_BSRAM_D		: std_logic_vector(7 downto 0);
	signal SDD_BSRAM_CE_N	: std_logic;
	signal SDD_BSRAM_OE_N	: std_logic;
	signal SDD_BSRAM_WE_N	: std_logic;
	signal SDD_REFRESH		: std_logic;
begin

	SNES : entity work.SNES
	port map(
		MCLK			=> MCLK,
		DSPCLK		=> ACLK,
		
		RST_N			=> RESET_N,
		ENABLE		=> '1',
		
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
		
		SYSCLKF_CE	=> SYSCLKF_CE,
		SYSCLKR_CE	=> SYSCLKR_CE,

		IRQ_N			=> IRQ_N,
			
		WSRAM_ADDR	=> WRAM_ADDR,
		WSRAM_D		=> WRAM_D,
		WSRAM_Q		=> WRAM_Q,
		WSRAM_CE_N	=> WRAM_CE_N,
		WSRAM_OE_N	=> WRAM_OE_N,
		WSRAM_WE_N	=> WRAM_WE_N,
			
		VRAM_ADDRA	=> VRAM1_ADDR,
		VRAM_ADDRB	=> VRAM2_ADDR,
		VRAM_DAI		=> VRAM1_DI,
		VRAM_DBI		=> VRAM2_DI,
		VRAM_DAO		=> VRAM1_DO,
		VRAM_DBO		=> VRAM2_DO,
		VRAM_RD_N	=> VRAM_OE_N,
		VRAM_WRA_N	=> VRAM1_WE_N,
		VRAM_WRB_N	=> VRAM2_WE_N,

		ARAM_ADDR	=> ARAM_ADDR,
		ARAM_D		=> ARAM_D,
		ARAM_Q		=> ARAM_Q,
		ARAM_CE_N	=> ARAM_CE_N,
		ARAM_OE_N	=> ARAM_OE_N,
		ARAM_WE_N	=> ARAM_WE_N,

		JOY1_DI		=> JOY1_DI,
		JOY2_DI		=> JOY2_DI,
		JOY_STRB		=> JOY_STRB,
		JOY1_CLK		=> JOY1_CLK,
		JOY2_CLK		=> JOY2_CLK,
		JOY1_P6		=> JOY1_P6,
		JOY2_P6		=> JOY2_P6,

		BLEND			=> BLEND,
		PAL			=> PAL,
		HIGH_RES		=> HIGH_RES,
		FIELD_OUT	=> FIELD,
		INTERLACE   => INTERLACE,
		DOTCLK		=> DOTCLK,

		RGB_OUT		=> RGB_OUT,
		HDE			=> HBLANKn,
		VDE			=> VBLANKn,
		HSYNC			=> HSYNC,
		VSYNC			=> VSYNC,

		DBG_SEL		=> (others =>'0'),
		DBG_REG		=> (others =>'0'),
		DBG_REG_WR	=> '0',
		DBG_DAT_IN	=> (others =>'0'),

		AUDIO_L		=> AUDIO_L,
		AUDIO_R		=> AUDIO_R
	);

	R <= RGB_OUT(7 downto 0);
	G <= RGB_OUT(15 downto 8);
	B <= RGB_OUT(23 downto 16);
	HBLANK <= not HBLANKn;
	VBLANK <= not VBLANKn;

	DSP_LHRomMap : entity work.DSP_LHRomMap
	port map(
		MCLK			=> MCLK,
		RST_N			=> RESET_N,
		
		CA				=> CA,
		DI				=> DO,
		DO				=> DLH_DO,
		CPURD_N		=> CPURD_N,
		CPUWR_N		=> CPUWR_N,
		
		PA				=> PA,
		PARD_N		=> PARD_N,
		PAWR_N		=> PAWR_N,
		
		ROMSEL_N		=> ROMSEL_N,
		RAMSEL_N		=> RAMSEL_N,
		
		SYSCLKF_CE	=> SYSCLKF_CE,
		SYSCLKR_CE	=> SYSCLKR_CE,
		REFRESH		=> DLH_REFRESH,

		IRQ_N			=> DLH_IRQ_N,
		
		ROM_ADDR		=> DLH_ROM_ADDR,
		ROM_Q			=> ROM_Q,
		ROM_CE_N		=> DLH_ROM_CE_N,
		ROM_OE_N		=> DLH_ROM_OE_N,
		ROM_WORD		=> DLH_ROM_WORD,

		BSRAM_ADDR	=> DLH_BSRAM_ADDR,
		BSRAM_D		=> DLH_BSRAM_D,
		BSRAM_Q		=> BSRAM_Q,
		BSRAM_CE_N	=> DLH_BSRAM_CE_N,
		BSRAM_OE_N	=> DLH_BSRAM_OE_N,
		BSRAM_WE_N	=> DLH_BSRAM_WE_N,

		MAP_CTRL		=> ROM_TYPE,
		ROM_MASK		=> ROM_MASK,
		BSRAM_MASK	=> RAM_MASK
	);

	CX4Map : entity work.CX4Map
	port map(
		MEM_CLK		=> MEM_CLK,
		MCLK			=> MCLK,
		RST_N			=> RESET_N,
		
		CA				=> CA,
		DI				=> DO,
		DO				=> CX4_DO,
		CPURD_N		=> CPURD_N,
		CPUWR_N		=> CPUWR_N,
		
		PA				=> PA,
		PARD_N		=> PARD_N,
		PAWR_N		=> PAWR_N,
		
		ROMSEL_N		=> ROMSEL_N,
		RAMSEL_N		=> RAMSEL_N,
		
		SYSCLKF_CE	=> SYSCLKF_CE,
		SYSCLKR_CE	=> SYSCLKR_CE,
		REFRESH		=> CX4_REFRESH,

		IRQ_N			=> CX4_IRQ_N,
		
		ROM_ADDR		=> CX4_ROM_ADDR,
		ROM_Q			=> ROM_Q,
		ROM_CE_N		=> CX4_ROM_CE_N,
		ROM_OE_N		=> CX4_ROM_OE_N,
		ROM_WORD		=> CX4_ROM_WORD,

		BSRAM_ADDR	=> CX4_BSRAM_ADDR,
		BSRAM_D		=> CX4_BSRAM_D,
		BSRAM_Q		=> BSRAM_Q,
		BSRAM_CE_N	=> CX4_BSRAM_CE_N,
		BSRAM_OE_N	=> CX4_BSRAM_OE_N,
		BSRAM_WE_N	=> CX4_BSRAM_WE_N,

		MAP_CTRL		=> ROM_TYPE,
		ROM_MASK		=> ROM_MASK,
		BSRAM_MASK	=> RAM_MASK
	);
	
	SDD1Map : entity work.SDD1Map
	port map(
		MCLK			=> MCLK,
		RST_N			=> RESET_N,

		CA				=> CA,
		DI				=> DO,
		DO				=> SDD_DO,
		CPURD_N		=> CPURD_N,
		CPUWR_N		=> CPUWR_N,

		PA				=> PA,
		PARD_N		=> PARD_N,
		PAWR_N		=> PAWR_N,

		ROMSEL_N		=> ROMSEL_N,
		RAMSEL_N		=> RAMSEL_N,

		SYSCLKF_CE	=> SYSCLKF_CE,
		SYSCLKR_CE	=> SYSCLKR_CE,
		REFRESH		=> SDD_REFRESH,

		IRQ_N			=> SDD_IRQ_N,

		ROM_ADDR		=> SDD_ROM_ADDR,
		ROM_Q			=> ROM_Q,
		ROM_CE_N		=> SDD_ROM_CE_N,
		ROM_OE_N		=> SDD_ROM_OE_N,
		ROM_WORD		=> SDD_ROM_WORD,

		BSRAM_ADDR	=> SDD_BSRAM_ADDR,
		BSRAM_D		=> SDD_BSRAM_D,
		BSRAM_Q		=> BSRAM_Q,
		BSRAM_CE_N	=> SDD_BSRAM_CE_N,
		BSRAM_OE_N	=> SDD_BSRAM_OE_N,
		BSRAM_WE_N	=> SDD_BSRAM_WE_N,

		MAP_CTRL		=> ROM_TYPE,
		ROM_MASK		=> ROM_MASK,
		BSRAM_MASK	=> RAM_MASK
	);

	DI          <= DLH_DO         and CX4_DO         and SDD_DO;
	IRQ_N       <= DLH_IRQ_N      and CX4_IRQ_N      and SDD_IRQ_N;
	ROM_ADDR    <= DLH_ROM_ADDR   and CX4_ROM_ADDR   and SDD_ROM_ADDR;
	ROM_CE_N    <= DLH_ROM_CE_N   and CX4_ROM_CE_N   and SDD_ROM_CE_N;
	ROM_OE_N    <= DLH_ROM_OE_N   and CX4_ROM_OE_N   and SDD_ROM_OE_N;
	BSRAM_ADDR  <= DLH_BSRAM_ADDR and CX4_BSRAM_ADDR and SDD_BSRAM_ADDR;
	BSRAM_D     <= DLH_BSRAM_D    and CX4_BSRAM_D    and SDD_BSRAM_D;
	BSRAM_CE_N  <= DLH_BSRAM_CE_N and CX4_BSRAM_CE_N and SDD_BSRAM_CE_N;
	BSRAM_OE_N  <= DLH_BSRAM_OE_N and CX4_BSRAM_OE_N and SDD_BSRAM_OE_N;
	BSRAM_WE_N  <= DLH_BSRAM_WE_N and CX4_BSRAM_WE_N and SDD_BSRAM_WE_N;

	ROM_WORD    <= DLH_ROM_WORD   or  CX4_ROM_WORD   or  SDD_ROM_WORD;
	REFRESH     <= DLH_REFRESH    or  CX4_REFRESH    or  SDD_REFRESH;

end rtl;
