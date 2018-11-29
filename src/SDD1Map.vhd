library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity SDD1Map is
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
end SDD1Map;

architecture rtl of SDD1Map is

	signal SDD1_ROM_A : std_logic_vector(23 downto 0);
	signal BSRAM_ADDR : std_logic_vector(19 downto 0);
	signal BSRAM_CS_N 	: std_logic;
	
	signal SRAM1_DO, SRAM2_DO : std_logic_vector(7 downto 0);
	signal ROM_DO	: std_logic_vector(15 downto 0);
	signal SDD1_DO	: std_logic_vector(7 downto 0);

begin
	
	BSRAM_ADDR <= "0" & CA(19 downto 16) & CA(14 downto 0);
	
	ROM_DO <= SRAM2_DO & SRAM1_DO;
	
	-- SDD1
	SDD1 : entity work.SDD1
	port map(
		RST_N			=> RST_N,
		CLK			=> MCLK,
		ENABLE		=> ENABLE,

		CA				=> CA,
		CPURD_N		=> CPURD_N,
		CPUWR_N		=> CPUWR_N,
		DO				=> SDD1_DO,
		DI				=> DI,
		
		SYSCLK		=> SYSCLK,

		ROM_A			=> SDD1_ROM_A,
		ROM_DO		=> ROM_DO,
		
		SRAM_CS_N	=> BSRAM_CS_N,
		
		DBG_REG		=> DBG_REG,
		DBG_DAT_OUT	=> DBG_DAT_OUT
	);

	SRAM1_ADDR <= LD_ADDR(22 downto 1) when LD_EN = '1' else (SDD1_ROM_A(22 downto 1) and ROM_MASK(22 downto 1));
	SRAM1_CE_N <= LD_ADDR(0) when LD_EN = '1' else '0';
	SRAM1_OE_N <= LD_WR when LD_EN = '1' else '0';
	SRAM1_WE_N <= not LD_WR when LD_EN = '1' else '1';
	SRAM1_DO <= SRAM1_DQ;
	SRAM1_DQ <= LD_DI when LD_EN = '1' and LD_WR = '1' else "ZZZZZZZZ"; 
	
	SRAM2_ADDR <= LD_ADDR(22 downto 1) when LD_EN = '1' else
					  "11" & (BSRAM_ADDR and BSRAM_MASK(19 downto 0)) when BSRAM_CS_N = '0' else 
					  (SDD1_ROM_A(22 downto 1) and ROM_MASK(22 downto 1));
	SRAM2_CE_N <= not LD_ADDR(0) when LD_EN = '1' else
					  '0' when BSRAM_CS_N = '0' else
					  '0';
	SRAM2_OE_N <= LD_WR when LD_EN = '1' else
					  CPURD_N when BSRAM_CS_N = '0' else 
					  '0';
	SRAM2_WE_N <= not LD_WR when LD_EN = '1' else 
					  CPUWR_N when BSRAM_CS_N = '0' else 
					  '1';
	SRAM2_DO <= SRAM2_DQ;
	SRAM2_DQ <= LD_DI when LD_EN = '1' and LD_WR = '1' else "ZZZZZZZZ"; 
	
	DO <= SRAM2_DO when BSRAM_CS_N = '0' else SDD1_DO;
	
	IRQ_N <= '1';
	
	BRK_OUT <= '0';

end rtl;