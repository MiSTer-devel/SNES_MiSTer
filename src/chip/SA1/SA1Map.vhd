library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity SA1Map is
	port(
		MCLK			: in std_logic;
		RST_N			: in std_logic;
		ENABLE		: in std_logic := '1';
		
		CA   			: in std_logic_vector(23 downto 0);
		DI				: in std_logic_vector(7 downto 0);
		DO				: out std_logic_vector(7 downto 0);
		CPURD_N		: in std_logic;
		CPUWR_N		: in std_logic;
		
		PA				: in std_logic_vector(7 downto 0);
		PARD_N		: in std_logic;
		PAWR_N		: in std_logic;
		
		ROMSEL_N		: in std_logic;
		RAMSEL_N		: in std_logic;
		
		SYSCLKF_CE	: in std_logic;
		SYSCLKR_CE	: in std_logic;
		
		REFRESH		: in std_logic;
		
		PAL			: in std_logic;
		
		IRQ_N			: out std_logic;

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

		MAP_CTRL		: in std_logic_vector(7 downto 0);
		ROM_MASK		: in std_logic_vector(23 downto 0);
		BSRAM_MASK	: in std_logic_vector(23 downto 0);
		
		BRK_OUT		: out std_logic;
		DBG_REG		: in std_logic_vector(7 downto 0) := (others => '0');
		DBG_DAT_IN	: in std_logic_vector(7 downto 0) := (others => '0');
		DBG_DAT_OUT	: out std_logic_vector(7 downto 0);
		DBG_DAT_WR	: in std_logic := '0'
	);
end SA1Map;

architecture rtl of SA1Map is

	signal ROM_A		: std_logic_vector(22 downto 0);
	signal ROM_DI		: std_logic_vector(15 downto 0);
	signal ROM_RD_N	: std_logic;
	
	signal BWRAM_A 	: std_logic_vector(17 downto 0);
	signal BWRAM_DO 	: std_logic_vector(7 downto 0);
	signal BWRAM_OE_N : std_logic;
	signal BWRAM_WE_N : std_logic;
	
	signal SA1_DO		: std_logic_vector(7 downto 0);
	signal SA1_IRQ_N	: std_logic;
	
	signal MAP_SEL		: std_logic;

begin

	MAP_SEL <= '1' when MAP_CTRL(7 downto 4) = X"6" else '0';
	
	SA1 : entity work.SA1
	port map(
		CLK			=> MCLK,
		RST_N			=> RST_N and MAP_SEL,
		ENABLE		=> ENABLE,

		SNES_A		=> CA,
		SNES_DO		=> SA1_DO,
		SNES_DI		=> DI,
		SNES_RD_N	=> CPURD_N,
		SNES_WR_N	=> CPUWR_N,
		
		SYSCLKF_CE	=> SYSCLKF_CE,
		SYSCLKR_CE	=> SYSCLKR_CE,
		
		REFRESH		=> REFRESH,
		
		PAL			=> PAL,
		
		ROM_A			=> ROM_A,
		ROM_DI		=> ROM_Q,
		ROM_RD_N		=> ROM_RD_N,
		
		BWRAM_A		=> BWRAM_A,
		BWRAM_DI		=> BSRAM_Q,
		BWRAM_DO		=> BWRAM_DO,
		BWRAM_OE_N	=> BWRAM_OE_N,
		BWRAM_WE_N	=> BWRAM_WE_N,
		
		IRQ_N			=> SA1_IRQ_N,
		
		BRK_OUT		=> BRK_OUT,
		DBG_REG  	=> DBG_REG,
		DBG_DAT_IN	=> DBG_DAT_IN,
		DBG_DAT_OUT	=> DBG_DAT_OUT,
		DBG_DAT_WR	=> DBG_DAT_WR
	);
	
	ROM_ADDR 	<= (others => '1') when MAP_SEL = '0' else (ROM_A and ROM_MASK(22 downto 0));
	ROM_CE_N 	<= not MAP_SEL;
	ROM_OE_N 	<= ROM_RD_N or not MAP_SEL;
	ROM_WORD		<= MAP_SEL;
	
	BSRAM_ADDR 	<= (others => '1') when MAP_SEL = '0' else ("0000" & BWRAM_A(15 downto 0));
	BSRAM_CE_N 	<= not MAP_SEL;
	BSRAM_OE_N 	<= BWRAM_OE_N or not MAP_SEL;
	BSRAM_WE_N 	<= BWRAM_WE_N or not MAP_SEL;
	BSRAM_D    	<= (others => '1') when MAP_SEL = '0' else BWRAM_DO;
	
	DO				<= (others => '1') when MAP_SEL = '0' else SA1_DO;
	IRQ_N 		<= SA1_IRQ_N or not MAP_SEL;

end rtl;