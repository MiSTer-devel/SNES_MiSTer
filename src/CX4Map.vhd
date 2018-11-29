library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity CX4Map is
	port(
		CLK100		: in std_logic;
		MCLK			: in std_logic;
		RST_N			: in std_logic;
		ENABLE		: in std_logic;
		
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
		
		SYSCLK		: in std_logic;
		REFRESH		: in std_logic;
		
		IRQ_N			: out std_logic;

		SRAM1_ADDR	: out std_logic_vector(21 downto 0);
		SRAM1_DQ		: inout std_logic_vector(7 downto 0);
		SRAM1_CE_N	: out std_logic;
		SRAM1_OE_N	: out std_logic;
		SRAM1_WE_N	: out std_logic;
		
		SRAM2_ADDR	: out std_logic_vector(21 downto 0);
		SRAM2_DQ		: inout std_logic_vector(7 downto 0);
		SRAM2_CE_N	: out std_logic;
		SRAM2_OE_N	: out std_logic;
		SRAM2_WE_N	: out std_logic;

		MAP_CTRL		: in std_logic_vector(7 downto 0);
		ROM_MASK		: in std_logic_vector(23 downto 0);
		BSRAM_MASK	: in std_logic_vector(23 downto 0);
		
		LD_ADDR   	: in std_logic_vector(23 downto 0);
		LD_DI			: in std_logic_vector(7 downto 0);
		LD_WR			: in std_logic;
		LD_EN			: in std_logic;
		
		BRK_OUT		: out std_logic;
		DBG_REG		: in std_logic_vector(7 downto 0);
		DBG_DAT_IN	: in std_logic_vector(7 downto 0);
		DBG_DAT_OUT	: out std_logic_vector(7 downto 0);
		DBG_DAT_WR	: in std_logic
	);
end CX4Map;

architecture rtl of CX4Map is

	signal CX4_CLK	: std_logic;
	signal CX4_A 	: std_logic_vector(21 downto 0);
	signal CX4_DI, CX4_DO : std_logic_vector(7 downto 0);
	signal SRAM_CE_N, ROM_CE1_N, ROM_CE2_N, CX4_OE_N, CX4_WE_N : std_logic;
	signal CART_ADDR, BSRAM_ADDR : std_logic_vector(21 downto 0);
	signal SRAM1_DO, SRAM2_DO : std_logic_vector(7 downto 0);

begin
	
	pll : entity work.cx4pll
	port map(
		inclk0	=> CLK100,
		c0			=> CX4_CLK
	);

	CX4 : entity work.CX4
	port map(
		CLK			=> CX4_CLK,
		RST_N			=> RST_N,
		ENABLE		=> ENABLE,

		ADDR			=> CA,
		DO				=> DO,
		DI				=> DI,
		RD_N			=> CPURD_N,
		WR_N			=> CPUWR_N,
		
		IRQ_N			=> IRQ_N,
		
		BUS_A			=> CX4_A,
		BUS_DI		=> CX4_DI,
		BUS_DO		=> CX4_DO,
		BUS_OE_N		=> CX4_OE_N,
		BUS_WE_N		=> CX4_WE_N,
		ROM_CE1_N	=> ROM_CE1_N,
		ROM_CE2_N	=> ROM_CE2_N,
		SRAM_CE_N	=> SRAM_CE_N,
		
		MAPPER		=> MAP_CTRL(0),
		
		BRK_OUT		=> BRK_OUT,
		DBG_REG  	=> DBG_REG,
		DBG_DAT_IN	=> DBG_DAT_IN,
		DBG_DAT_OUT	=> DBG_DAT_OUT,
		DBG_DAT_WR	=> DBG_DAT_WR
	);
	
	CART_ADDR <= "0" & not ROM_CE2_N & CX4_A(20 downto 16) & CX4_A(14 downto 0);
	BSRAM_ADDR <= "00" & CX4_A(20 downto 16) & CX4_A(14 downto 0);

	SRAM1_ADDR <= LD_ADDR(21 downto 0) when LD_EN = '1' else (CART_ADDR and ROM_MASK(21 downto 0));
	SRAM1_CE_N <= LD_ADDR(22) when LD_EN = '1' else ROM_CE1_N and ROM_CE2_N;
	SRAM1_OE_N <= LD_WR when LD_EN = '1' else CX4_OE_N;
	SRAM1_WE_N <= not LD_WR when LD_EN = '1' else '1';
	SRAM1_DO <= SRAM1_DQ;
	SRAM1_DQ <= LD_DI when LD_EN = '1' and LD_WR = '1' else "ZZZZZZZZ"; 
	
	SRAM2_ADDR <= (BSRAM_ADDR and BSRAM_MASK(21 downto 0));
	SRAM2_CE_N <= SRAM_CE_N;
	SRAM2_OE_N <= CX4_OE_N;
	SRAM2_WE_N <= CX4_WE_N;
	SRAM2_DO <= SRAM2_DQ;
	SRAM2_DQ <= CX4_DO when CX4_WE_N = '0' and SRAM_CE_N = '0' else "ZZZZZZZZ"; 
	
	CX4_DI <= SRAM2_DO when SRAM_CE_N = '0' else SRAM1_DO;

end rtl;