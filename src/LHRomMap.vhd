library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity LHRomMap is
	port(
		MCLK50		: in std_logic;
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

		MAP_CTRL		: in std_logic_vector(7 downto 0);
		ROM_MASK		: in std_logic_vector(23 downto 0);
		BSRAM_MASK	: in std_logic_vector(23 downto 0);
	
		BRK_OUT		: out std_logic;
		DBG_REG		: in std_logic_vector(7 downto 0);
		DBG_DAT_IN	: in std_logic_vector(7 downto 0);
		DBG_DAT_OUT	: out std_logic_vector(7 downto 0);
		DBG_DAT_WR	: in std_logic
	);
end LHRomMap;

architecture rtl of LHRomMap is

	signal CART_ADDR 	: std_logic_vector(22 downto 0);
	signal BRAM_ADDR  : std_logic_vector(19 downto 0);
	signal BSRAM_SEL 	: std_logic;

begin
	
	process( CA, MAP_CTRL, ROMSEL_N, RAMSEL_N, BSRAM_MASK )
	begin
		case MAP_CTRL(3 downto 0) is
			when x"0" =>							-- LoROM
				CART_ADDR <= "0" & CA(22 downto 16) & CA(14 downto 0);
				BRAM_ADDR <= CA(20 downto 16) & CA(14 downto 0);
				if CA(22 downto 20) = "111" and CA(15) = '0' and ROMSEL_N = '0' and BSRAM_MASK(10) = '1' then
					BSRAM_SEL <= '1';
				else
					BSRAM_SEL <= '0';
				end if;
			when x"1" =>							-- HiROM
				CART_ADDR <= "0" & CA(21 downto 0);
				BRAM_ADDR <= "00" & CA(20 downto 16) & CA(12 downto 0);
				if CA(22 downto 21) = "01" and CA(15 downto 13) = "011" and BSRAM_MASK(10) = '1' then
					BSRAM_SEL <= '1';
				else
					BSRAM_SEL <= '0';
				end if;
			when x"5" =>							-- ExHiROM
				CART_ADDR <= (not CA(23)) & CA(21 downto 0);
				BRAM_ADDR <= CA(19 downto 0);
				if CA(22 downto 21) = "01" and CA(15 downto 13) = "011" and BSRAM_MASK(10) = '1' then
					BSRAM_SEL <= '1';
				else
					BSRAM_SEL <= '0';
				end if;
			when others =>
				CART_ADDR <= (not CA(23)) & CA(21 downto 0);
				BRAM_ADDR <= CA(19 downto 0);
				BSRAM_SEL <= '0';
		end case;
	end process;

	ROM_ADDR <= CART_ADDR(22 downto 0) and ROM_MASK(22 downto 0);
	ROM_CE_N <= ROMSEL_N;
	ROM_OE_N <= CPURD_N;

	BSRAM_ADDR <= BRAM_ADDR and BSRAM_MASK(19 downto 0);
	BSRAM_CE_N <= not BSRAM_SEL;
	BSRAM_OE_N <= CPURD_N;
	BSRAM_WE_N <= CPUWR_N;
	BSRAM_D <= DI;

	DO <= BSRAM_Q when BSRAM_SEL = '1' else ROM_Q;

	IRQ_N <= '1';

	BRK_OUT <= '0';
	DBG_DAT_OUT <= (others => '0');
	
end rtl;