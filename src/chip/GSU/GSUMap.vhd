library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity GSUMap is
	port(
		MEM_CLK		: in std_logic;	--85MHz
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
		REFRESH		: out std_logic;
		
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
		
		CLS_SLOW		: out std_logic;
		CLS_FULL		: in std_logic;

		BRK_OUT		: out std_logic;
		DBG_REG		: in std_logic_vector(7 downto 0) := (others => '0');
		DBG_DAT_IN	: in std_logic_vector(7 downto 0) := (others => '0');
		DBG_DAT_OUT	: out std_logic_vector(7 downto 0);
		DBG_DAT_WR	: in std_logic := '0'
	);
end GSUMap;

architecture rtl of GSUMap is

	signal ROM_A 		: std_logic_vector(20 downto 0);
	signal ROM_RD_N 	: std_logic;
	signal RAM_A 		: std_logic_vector(16 downto 0);
	signal RAM_DO 		: std_logic_vector(7 downto 0);
	signal RAM_CE_N 	: std_logic;
	signal RAM_WE_N 	: std_logic;
	
	signal GSU_DO 		: std_logic_vector(7 downto 0);
	signal GSU_IRQ_N	: std_logic;
	signal CLS			: std_logic;
	
	signal MAP_SEL	  	: std_logic;
	
begin

	MAP_SEL <= '1' when MAP_CTRL(7 downto 4) = X"7" else '0';
	
	GSU : entity work.GSU
	port map(
		CLK			=> MCLK,
		MEM_CLK		=> MEM_CLK,
		RST_N			=> RST_N and MAP_SEL,
		ENABLE		=> ENABLE,

		ADDR			=> CA,
		DO				=> GSU_DO,
		DI				=> DI,
		RD_N			=> CPURD_N,
		WR_N			=> CPUWR_N,
		
		SYSCLKF_CE	=> SYSCLKF_CE,
		SYSCLKR_CE	=> SYSCLKR_CE,
		
		IRQ_N			=> GSU_IRQ_N,
		
		ROM_A			=> ROM_A,
		ROM_DI		=> ROM_Q(7 downto 0),
		ROM_RD_N		=> ROM_RD_N,
		
		RAM_A			=> RAM_A,
		RAM_DI		=> BSRAM_Q,
		RAM_DO		=> RAM_DO,
		RAM_WE_N		=> RAM_WE_N,
		RAM_CE_N		=> RAM_CE_N,
				
		CLS_OUT		=> CLS,
		CLS_FULL		=> CLS_FULL,

		BRK_OUT		=> BRK_OUT,
		DBG_REG  	=> DBG_REG,
		DBG_DAT_IN	=> DBG_DAT_IN,
		DBG_DAT_OUT	=> DBG_DAT_OUT,
		DBG_DAT_WR	=> DBG_DAT_WR
	);
	
	CLS_SLOW		<= MAP_SEL and not CLS;
	
	ROM_ADDR 	<= (others => '1') when MAP_SEL = '0' else ("00" & ROM_A) and ROM_MASK(22 downto 0);
	ROM_CE_N 	<= not MAP_SEL;
	ROM_OE_N 	<= ROM_RD_N or not MAP_SEL;
	ROM_WORD		<= '0';
	
	BSRAM_ADDR 	<= (others => '1') when MAP_SEL = '0' else ("0000" & RAM_A(15 downto 0));
	BSRAM_CE_N 	<= RAM_CE_N or not MAP_SEL;
	BSRAM_OE_N 	<= not RAM_WE_N or not MAP_SEL;
	BSRAM_WE_N 	<= RAM_WE_N or not MAP_SEL;
	BSRAM_D    	<= (others => '1') when MAP_SEL = '0' else RAM_DO;
	
	DO				<= (others => '1') when MAP_SEL = '0' else GSU_DO;
	IRQ_N 		<= GSU_IRQ_N or not MAP_SEL;

	REFRESH 		<= '0';

end rtl;