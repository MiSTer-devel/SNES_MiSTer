library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity DSPMap is
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
end DSPMap;

architecture rtl of DSPMap is

	signal DSP_CLK	: std_logic;
	signal CART_ADDR 	: std_logic_vector(21 downto 0);
	signal BRAM_ADDR : std_logic_vector(19 downto 0);
	signal BSRAM_SEL 	: std_logic;
	signal DSP_SEL	: std_logic;
	
	signal SRAM1_DO, SRAM2_DO : std_logic_vector(7 downto 0);
	signal DSP_DO : std_logic_vector(7 downto 0);
	signal DSP_A0	: std_logic;
	signal DSP_CS_N : std_logic;
	signal DSP_CE	: std_logic;

begin
	
	CEGen : entity work.CEGen
	port map(
		CLK     => MCLK,
		RST_N   => RST_N,
		IN_CLK  => 2147727,
		OUT_CLK =>  760000,
		CE      => DSP_CE
	);

	process( CA, MAP_CTRL, ROMSEL_N, BSRAM_MASK )
	begin
		case MAP_CTRL(3 downto 0) is
			when x"0" =>							-- LoROM
				CART_ADDR <= CA(22 downto 16) & CA(14 downto 0);
				BRAM_ADDR <= CA(20 downto 16) & CA(14 downto 0);
				if CA(22 downto 20) = "111" and CA(15) = '0' and ROMSEL_N = '0' and BSRAM_MASK(10) = '1' then
					BSRAM_SEL <= '1';
				else
					BSRAM_SEL <= '0';
				end if;
				if CA(22 downto 21) = "01" and CA(15) = '1' then	--20-3F/a0-bf:8000-FFFF
					DSP_SEL <= '1';
				else
					DSP_SEL <= '0';
				end if;
				DSP_A0 <= CA(14);
			when x"1" =>							-- HiROM
				CART_ADDR <= CA(21 downto 0);
				BRAM_ADDR <= "00" & CA(20 downto 16) & CA(12 downto 0);
				if CA(22 downto 21) = "01" and CA(15 downto 13) = "011" and BSRAM_MASK(10) = '1' then
					BSRAM_SEL <= '1';
				else
					BSRAM_SEL <= '0';
				end if;
				if CA(22 downto 21) = "00" and CA(15 downto 13) = "011" then	--00-1F/80-9f:6000-7FFF
					DSP_SEL <= '1';
				else
					DSP_SEL <= '0';
				end if;
				DSP_A0 <= CA(12);
			when others =>
				CART_ADDR <= CA(21 downto 0);
				BRAM_ADDR <= CA(19 downto 0);
				BSRAM_SEL <= '0';
				DSP_SEL <= '0';
				DSP_A0 <= '1';
		end case;
	end process;
	
	DSP_CS_N <= not DSP_SEL;
	
	DSPn : entity work.DSPn
	port map(
		CLK			=> MCLK,
		CE				=> DSP_CE,
		RST_N			=> RST_N,
		ENABLE		=> ENABLE,
		A0				=> DSP_A0,
		DI				=> DI,
		DO				=> DSP_DO,
		CS_N			=> DSP_CS_N,
		RD_N			=> CPURD_N,
		WR_N			=> CPUWR_N,
		
		VER			=> MAP_CTRL(5 downto 4),
		
		BRK_OUT		=> BRK_OUT,
		DBG_REG  	=> DBG_REG,
		DBG_DAT_IN	=> DBG_DAT_IN,
		DBG_DAT_OUT	=> DBG_DAT_OUT,
		DBG_DAT_WR	=> DBG_DAT_WR
	);

	ROM_ADDR <= "0" & (CART_ADDR(21 downto 0) and ROM_MASK(21 downto 0));
	ROM_CE_N <= ROMSEL_N;
	ROM_OE_N <= CPURD_N;
	
	BSRAM_ADDR <= BRAM_ADDR and BSRAM_MASK(19 downto 0);
	BSRAM_CE_N <= not BSRAM_SEL;
	BSRAM_OE_N <= CPURD_N;
	BSRAM_WE_N <= CPUWR_N;
	BSRAM_D <= DI;
	
	DO <= DSP_DO when DSP_SEL = '1' else
			BSRAM_Q when BSRAM_SEL = '1' else
			ROM_Q;

	
	IRQ_N <= '1';
	
end rtl;