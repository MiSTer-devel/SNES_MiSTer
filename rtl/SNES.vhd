library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity SNES is
	port(
		MCLK			: in std_logic;
		DSPCLK		: in std_logic;
		
		RST_N			: in std_logic;
		ENABLE		: in std_logic;
		PAL			: in std_logic;
		BLEND			: in std_logic;
		
		CA       	: out std_logic_vector(23 downto 0);
		CPURD_N		: out std_logic;
		CPUWR_N		: out std_logic;
		
		PA				: out std_logic_vector(7 downto 0);
		PARD_N		: out std_logic;
		PAWR_N		: out std_logic;
		DI				: in std_logic_vector(7 downto 0);
		DO				: out std_logic_vector(7 downto 0);
		
		RAMSEL_N		: out std_logic;
		ROMSEL_N		: out std_logic;
		
		SYSCLKF_CE	: out std_logic;
		SYSCLKR_CE	: out std_logic;
		REFRESH		: out std_logic;
		
		IRQ_N			: in std_logic;
		
		WSRAM_ADDR	: out std_logic_vector(16 downto 0);
		WSRAM_D		: out std_logic_vector(7 downto 0);
		WSRAM_Q		: in  std_logic_vector(7 downto 0);
		WSRAM_CE_N	: out std_logic;
		WSRAM_OE_N	: out std_logic;
		WSRAM_WE_N	: out std_logic;
		
		VRAM_ADDRA	: out std_logic_vector(15 downto 0);
		VRAM_ADDRB	: out std_logic_vector(15 downto 0);
		VRAM_DAI		: in std_logic_vector(7 downto 0);
		VRAM_DBI		: in std_logic_vector(7 downto 0);
		VRAM_DAO		: out std_logic_vector(7 downto 0);
		VRAM_DBO		: out std_logic_vector(7 downto 0);
		VRAM_WRA_N	: out std_logic;
		VRAM_WRB_N	: out std_logic;
		VRAM_RD_N	: out std_logic;
		
		ARAM_ADDR	: out std_logic_vector(15 downto 0);
		ARAM_D		: out std_logic_vector(7 downto 0);
		ARAM_Q		: in  std_logic_vector(7 downto 0);
		ARAM_CE_N	: out std_logic;
		ARAM_OE_N	: out std_logic;
		ARAM_WE_N	: out std_logic;
		
		HIGH_RES		: out std_logic;
		FIELD_OUT	: out std_logic;
		INTERLACE	: out std_logic;
		V224_MODE	: out std_logic;
		DOTCLK		: out std_logic;

		RGB_OUT 		: out std_logic_vector(23 downto 0);
		HDE			: out std_logic;
		VDE			: out std_logic;
		HSYNC			: out std_logic;
		VSYNC			: out std_logic;

		JOY1_DI		: in std_logic_vector(1 downto 0);
		JOY2_DI		: in std_logic_vector(1 downto 0);
		JOY_STRB		: out std_logic;
		JOY1_CLK		: out std_logic;
		JOY2_CLK		: out std_logic;
		JOY1_P6		: out std_logic;
		JOY2_P6		: out std_logic;
		JOY2_P6_in	: in std_logic;

		LRCK			: out std_logic;
		BCK			: out std_logic;
		SDAT			: out std_logic;

		DBG_SEL		: in std_logic_vector(7 downto 0);
		DBG_REG		: in std_logic_vector(7 downto 0);
		DBG_REG_WR	: in std_logic;
		DBG_DAT_IN	: in std_logic_vector(7 downto 0);
		DBG_DAT_OUT	: out std_logic_vector(7 downto 0);
		DBG_BREAK	: out std_logic;

		GG_EN			: in std_logic;
		GG_CODE		: in std_logic_vector(128 downto 0);
		GG_RESET		: in std_logic;
		GG_AVAILABLE: out std_logic;
		
		TURBO			: in std_logic;

		AUDIO_L		: out std_logic_vector(15 downto 0);
		AUDIO_R		: out std_logic_vector(15 downto 0)
	);
end SNES;

architecture rtl of SNES is

	-- SCPU
	signal INT_CA : std_logic_vector(23 downto 0);
	signal INT_CPURD_N : std_logic;
	signal INT_CPUWR_N : std_logic;
	signal CPU_DI : std_logic_vector(7 downto 0);
	signal CPU_DO : std_logic_vector(7 downto 0);
	signal INT_RAMSEL_N : std_logic;
	signal INT_ROMSEL_N : std_logic;
	signal INT_PA : std_logic_vector(7 downto 0);
	signal INT_PARD_N : std_logic;
	signal INT_PAWR_N : std_logic;
	signal JPIO67 : std_logic_vector(7 downto 6);
	signal INT_SYSCLKF_CE	: std_logic;
	signal INT_SYSCLKR_CE	: std_logic;

	signal BUSB_DO	: std_logic_vector(7 downto 0);
	signal BUSA_SEL : std_logic;
	signal BUSB_SEL : std_logic;

	signal WRAM_A : std_logic_vector(16 downto 0);
	signal WRAM_DO, WRAM_DI	: std_logic_vector(7 downto 0);
	signal WRAM_CE2_N, WRAM_OE2_N, WRAM_WE2_N	: std_logic; 

	-- PPU
	signal INT_HBLANK, INT_VBLANK : std_logic;
	signal PPU_DO : std_logic_vector(7 downto 0);
	signal PPU_DI : std_logic_vector(7 downto 0);

	-- APU
	signal SMP_CE: std_logic;
	signal SMP_A : std_logic_vector(15 downto 0);
	signal SMP_DO : std_logic_vector(7 downto 0);
	signal SMP_DI : std_logic_vector(7 downto 0);
	signal SMP_WE : std_logic;
	signal SMP_CPU_DO : std_logic_vector(7 downto 0);
	signal SMP_CPU_DI	: std_logic_vector(7 downto 0);
	signal SMP_EN : std_logic;

	signal APU_RAM_A : std_logic_vector(15 downto 0);
	signal APU_RAM_DO	: std_logic_vector(7 downto 0);
	signal APU_RAM_DI	: std_logic_vector(7 downto 0);
	signal APU_RAM_CE, APU_RAM_OE, APU_RAM_WE : std_logic;

	signal GENIE		: std_logic;
	signal GENIE_DO	: std_logic_vector(7 downto 0);
	signal GENIE_DI   : std_logic_vector(7 downto 0);

	-- DEBUG
	signal DBG_CPU_DAT, DBG_SCPU_DAT, DBG_WRAM_DAT, DBG_PPU_DAT, DBG_SMP_DAT, DBG_SPC700_DAT, DBG_DSP_DAT : std_logic_vector(7 downto 0);
	signal CPU_BRK, SMP_BRK, PPU_DBG_BRK	: std_logic;
	signal CPU_DBG_WR, WRAM_DBG_WR, SPC700_DAT_WR, SMP_DAT_WR, PPU_DBG_WR, DSP_DBG_WR : std_logic;

	component CODES is
		generic(
			ADDR_WIDTH  : in integer := 16;
			DATA_WIDTH  : in integer := 8
		);
		port(
			clk         : in  std_logic;
			reset       : in  std_logic;
			enable      : in  std_logic;
			addr_in     : in  std_logic_vector(23 downto 0);
			data_in     : in  std_logic_vector(7 downto 0);
			code        : in  std_logic_vector(128 downto 0);
			available   : out std_logic;
			genie_ovr   : out std_logic;
			genie_data  : out std_logic_vector(7 downto 0)
		);
	end component;

begin

	-- Game Genie
	GAMEGENIE : component CODES
	generic map(
		ADDR_WIDTH => 24,
		DATA_WIDTH => 8
	)
	port map(
		clk => MCLK,
		reset => GG_RESET,
		enable => not GG_EN,
		addr_in => INT_CA,
		data_in => CPU_DO,
		code => GG_CODE,
		available => GG_AVAILABLE,
		genie_ovr => GENIE,
		genie_data => GENIE_DO
	);
	
	GENIE_DI <= GENIE_DO when GENIE = '1' else CPU_DI;

	-- CPU
	CPU : entity work.SCPU
	port map(
		CLK			=> MCLK,
		RST_N			=> RST_N,
		
		ENABLE		=> ENABLE,
		
		HBLANK		=> INT_HBLANK,
		VBLANK		=> INT_VBLANK,
		
		IRQ_N			=> IRQ_N,
		
		CA				=> INT_CA,
		CPURD_N		=> INT_CPURD_N,
		CPUWR_N		=> INT_CPUWR_N,
		PA				=> INT_PA,
		PARD_N		=> INT_PARD_N,
		PAWR_N		=> INT_PAWR_N,
		DI				=> GENIE_DI,
		DO				=> CPU_DO,
		
		RAMSEL_N		=> INT_RAMSEL_N,
		ROMSEL_N		=> INT_ROMSEL_N,
		
		REFRESH		=> REFRESH,
		JPIO67		=> JPIO67,
		
		SYSCLKF_CE	=> INT_SYSCLKF_CE,
		SYSCLKR_CE	=> INT_SYSCLKR_CE,

		JOY1_DI		=> JOY1_DI,
		JOY2_DI		=> JOY2_DI,
		JOY_STRB		=> JOY_STRB,
		JOY1_CLK		=> JOY1_CLK,
		JOY2_CLK		=> JOY2_CLK,

		TURBO			=> TURBO,

		DBG_CPU_BRK => CPU_BRK,
		DBG_REG     => DBG_REG,
		DBG_DAT     => DBG_SCPU_DAT,
		DBG_DAT_IN  => DBG_DAT_IN,
		DBG_CPU_DAT => DBG_CPU_DAT,
		DBG_CPU_WR 	=> CPU_DBG_WR
	);

	BUSA_SEL <= '1' when INT_CA(22) = '0' and INT_CA(15 downto 8) /= x"21" else
					'1' when INT_CA(23 downto 16) >= x"40" and INT_CA(23 downto 16) <= x"7D" else 
					'1' when INT_CA(23 downto 16) >= x"C0" else
					'0';

	BUSB_SEL <= '1' when INT_PA(7) = '0' or INT_PA(7 downto 2) = "100000" else '0';
	BUSB_DO <= PPU_DO when INT_PA(7 downto 6) = "00" else 
				  SMP_CPU_DO when INT_PA(7 downto 6) = "01" else
				  WRAM_DO when INT_PA(7 downto 2) = "100000" else
				  x"FF";

	CPU_DI <= WRAM_DO when INT_RAMSEL_N = '0' else
				 DI when BUSA_SEL = '1' else
				 BUSB_DO when BUSB_SEL = '1' else
				 DI;



	-- WRAM
	WRAM_DI <= DI when BUSA_SEL = '1' else
				  BUSB_DO when INT_PARD_N = '0' else
				  CPU_DO;

	WRAM : entity work.SWRAM
	port map(
		CLK			=> MCLK,
		SYSCLK_CE	=> INT_SYSCLKF_CE,
		RST_N			=> RST_N,
		ENABLE		=> ENABLE,
		
		CA				=> INT_CA,
		CPURD_N		=> INT_CPURD_N,
		CPUWR_N		=> INT_CPUWR_N,
		RAMSEL_N		=> INT_RAMSEL_N,
		
		PA				=> INT_PA,
		PARD_N		=> INT_PARD_N,
		PAWR_N		=> INT_PAWR_N,
		
		DI				=> WRAM_DI,
		DO				=> WRAM_DO,
		
		RAM_A			=> WSRAM_ADDR,
		RAM_D			=> WSRAM_D,
		RAM_Q			=> WSRAM_Q,
		RAM_WE_N		=> WSRAM_WE_N,
		RAM_CE_N		=> WSRAM_CE_N,
		RAM_OE_N		=> WSRAM_OE_N,
		
		DBG_REG     => DBG_REG,
		DBG_DAT_OUT => DBG_WRAM_DAT,
		DBG_DAT_IN	=> DBG_DAT_IN,
		DBG_DAT_WR	=> WRAM_DBG_WR
	);
	

	-- PPU
	PPU_DI <= DI when BUSA_SEL = '1' else
				 WRAM_DO when INT_RAMSEL_N = '0' else
				 CPU_DO;
 
	PPU : entity work.SPPU
	port map(
		RST_N			=> RST_N,
		CLK			=> MCLK,
		SYSCLK_CE	=> INT_SYSCLKF_CE,
		ENABLE		=> ENABLE,
		
		PA				=> INT_PA,
		PARD_N		=> INT_PARD_N,
		PAWR_N		=> INT_PAWR_N,
		DI				=> PPU_DI,
		DO				=> PPU_DO,
		
		VRAM_ADDRA	=> VRAM_ADDRA,
		VRAM_ADDRB	=> VRAM_ADDRB,
		VRAM_DAI		=> VRAM_DAI,
		VRAM_DBI		=> VRAM_DBI,
		VRAM_DAO		=> VRAM_DAO,
		VRAM_DBO		=> VRAM_DBO,
		VRAM_RD_N	=> VRAM_RD_N,
		VRAM_WRA_N	=> VRAM_WRA_N,
		VRAM_WRB_N	=> VRAM_WRB_N,
		
		EXTLATCH		=> JPIO67(7) and JOY2_P6_in,
		
		BLEND			=> BLEND,
		PAL			=> PAL,
		HIGH_RES		=> HIGH_RES,
		DOTCLK		=> DOTCLK,
		FIELD_OUT	=> FIELD_OUT,
		INTERLACE   => INTERLACE,
		V224 			=> V224_MODE,

		COLOR_OUT 	=> RGB_OUT,
		HBLANK		=> INT_HBLANK,
		VBLANK		=> INT_VBLANK,
		HDE			=> HDE,
		VDE			=> VDE,
		HSYNC			=> HSYNC,
		VSYNC			=> VSYNC,

		DBG_REG 		=> DBG_REG,
		DBG_DAT_OUT => DBG_PPU_DAT,
		DBG_DAT_IN	=> DBG_DAT_IN,
		DBG_DAT_WR	=> PPU_DBG_WR,
		DBG_BRK		=> PPU_DBG_BRK
	);


	SMP_CPU_DI <= DI when BUSA_SEL = '1' else
					  WRAM_DO when INT_RAMSEL_N = '0' else
					  CPU_DO;
			 
	-- SMP
	SMP : entity work.SMP
	port map(
		CLK			=> DSPCLK,
		RST_N			=> RST_N,
		CE				=> SMP_CE,
		ENABLE		=> SMP_EN,
		SYSCLKF_CE	=> INT_SYSCLKF_CE,
		
		A				=> SMP_A,
		DI				=> SMP_DI,
		DO				=> SMP_DO,
		WE				=> SMP_WE,
			
		PA				=> INT_PA(1 downto 0),
		PARD_N		=> INT_PARD_N,
		PAWR_N		=> INT_PAWR_N,
		CPU_DI		=> SMP_CPU_DI,
		CPU_DO		=> SMP_CPU_DO,
		CS				=> INT_PA(6),
		CS_N			=> INT_PA(7),
		
		DBG_REG			=> DBG_REG,
		DBG_DAT_IN		=> DBG_DAT_IN,
		DBG_CPU_DAT 	=> DBG_SPC700_DAT,
		DBG_SMP_DAT		=> DBG_SMP_DAT,
		DBG_CPU_DAT_WR	=> SPC700_DAT_WR,
		DBG_SMP_DAT_WR	=> SMP_DAT_WR,
		BRK_OUT    		=> SMP_BRK
		
	);

	-- DSP 
	DSP: entity work.DSP 
	port map (
		CLK			=> DSPCLK,
		RST_N			=> RST_N,
		ENABLE		=> ENABLE,
		PAL			=> PAL,
				
		SMP_EN    	=> SMP_EN,
		SMP_A     	=> SMP_A,
		SMP_DO    	=> SMP_DO,
		SMP_DI 		=> SMP_DI,
		SMP_WE    	=> SMP_WE,
		SMP_CE    	=> SMP_CE,
				
		RAM_A 		=> ARAM_ADDR,
		RAM_D     	=> ARAM_D,
		RAM_Q     	=> ARAM_Q,
		RAM_CE_N 	=> ARAM_CE_N,
		RAM_OE_N 	=> ARAM_OE_N,
		RAM_WE_N 	=> ARAM_WE_N,
				
		LRCK 			=> LRCK,
		BCK 			=> BCK,
		SDAT 			=> SDAT,
		
		DBG_REG		=> DBG_REG,
		DBG_DAT_IN  => DBG_DAT_IN,
		DBG_DAT_OUT => DBG_DSP_DAT,
		DBG_DAT_WR	=> DSP_DBG_WR,
		
		AUDIO_L		=> AUDIO_L,
		AUDIO_R		=> AUDIO_R
	);

	CA <= INT_CA;
	CPURD_N <= INT_CPURD_N;
	CPUWR_N <= INT_CPUWR_N;
	
	PA <= INT_PA;
	PARD_N <= INT_PARD_N;
	PAWR_N <= INT_PAWR_N;
	
	RAMSEL_N	<= INT_RAMSEL_N;
	ROMSEL_N	<= INT_ROMSEL_N;
	
	DO <= BUSB_DO when INT_PARD_N = '0' else CPU_DO;
	
	SYSCLKF_CE <= INT_SYSCLKF_CE;
	SYSCLKR_CE <= INT_SYSCLKR_CE;
	
	CPU_DBG_WR <= DBG_SEL(0) and DBG_REG_WR;
	WRAM_DBG_WR <= DBG_SEL(2) and DBG_REG_WR;
	SPC700_DAT_WR <= DBG_SEL(3) and DBG_REG_WR;
	SMP_DAT_WR <= DBG_SEL(4) and DBG_REG_WR;
	PPU_DBG_WR <= DBG_SEL(5) and DBG_REG_WR;
	DSP_DBG_WR <= DBG_SEL(6) and DBG_REG_WR;

	DBG_DAT_OUT <= DBG_CPU_DAT when DBG_SEL(0) = '1' else 
						DBG_SCPU_DAT when DBG_SEL(1) = '1' else 
						DBG_WRAM_DAT when DBG_SEL(2) = '1' else 
						DBG_SPC700_DAT when DBG_SEL(3) = '1' else 
						DBG_SMP_DAT when DBG_SEL(4) = '1' else 
						DBG_PPU_DAT when DBG_SEL(5) = '1' else 
						DBG_DSP_DAT when DBG_SEL(6) = '1' else 
						x"00";


	DBG_BREAK <= CPU_BRK or SMP_BRK or PPU_DBG_BRK;

	JOY1_P6 <= JPIO67(6);
	JOY2_P6 <= JPIO67(7);

end rtl;

