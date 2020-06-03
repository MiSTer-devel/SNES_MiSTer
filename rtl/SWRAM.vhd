library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library STD;
use IEEE.NUMERIC_STD.ALL;

entity SWRAM is
	port(
		CLK			: in std_logic;
		SYSCLK_CE	: in std_logic;
		RST_N			: in std_logic;
		ENABLE		: in std_logic;
		
		CA       	: in std_logic_vector(23 downto 0);
		CPURD_N		: in std_logic;
		CPUWR_N		: in std_logic;
		RAMSEL_N		: in std_logic;
		
		PA				: in std_logic_vector(7 downto 0);
		PARD_N		: in std_logic;
		PAWR_N		: in std_logic;

		DI				: in std_logic_vector(7 downto 0);
		DO				: out std_logic_vector(7 downto 0);
		
		RAM_A   		: out std_logic_vector(16 downto 0);
		RAM_D 		: out std_logic_vector(7 downto 0);
		RAM_Q 		: in  std_logic_vector(7 downto 0);
		RAM_WE_N		: out std_logic;
		RAM_CE_N		: out std_logic;
		RAM_OE_N		: out std_logic;
		
		DBG_REG		: in std_logic_vector(7 downto 0);
		DBG_DAT_OUT	: out std_logic_vector(7 downto 0);
		DBG_DAT_IN	: in std_logic_vector(7 downto 0);
		DBG_DAT_WR	: in std_logic
	);
end SWRAM;

architecture rtl of SWRAM is

	signal WMADD : std_logic_vector(23 downto 0);
	
	--debug
	signal DBG_ADDR	: std_logic_vector(23 downto 0);
	signal DBG_DAT_WRr	: std_logic;

begin
	
	process( RST_N, CLK )
	begin
		if RST_N = '0' then
			WMADD <= (others => '0');
		elsif rising_edge(CLK) then
			if ENABLE = '1' and SYSCLK_CE = '1' then
				if PAWR_N = '0' then
					case PA is
						when x"80" =>
							if RAMSEL_N = '1'  then		--check if DMA use WRAM in ABUS
								WMADD <= std_logic_vector(unsigned(WMADD) + 1);
							end if;
						when x"81" =>
							WMADD(7 downto 0) <= DI;
						when x"82" =>
							WMADD(15 downto 8) <= DI;
						when x"83" =>
							WMADD(23 downto 16) <= DI;
						when others => null;
					end case;
				elsif PARD_N = '0' then
					case PA is
						when x"80" =>
							if RAMSEL_N = '1' then		--check if DMA use WRAM in ABUS
								WMADD <= std_logic_vector(unsigned(WMADD) + 1);
							end if;
						when others => null;
					end case;
				end if;
			end if;
		end if;
	end process;
	
	DO <= RAM_Q;
	RAM_D <= x"FF" when PA = x"80" and RAMSEL_N = '0' else DI;

	RAM_A 	<= DBG_ADDR(16 downto 0) when ENABLE = '0' else 
					CA(16 downto 0) when RAMSEL_N = '0' else
					WMADD(16 downto 0);
					
	RAM_CE_N <= '0' when ENABLE = '0' else 
					'0' when RAMSEL_N = '0' else
					'0' when PA = x"80" else 
					'1';
					
	RAM_OE_N <= '0' when ENABLE = '0' else 
					'0' when RAMSEL_N = '0' and CPURD_N = '0' else
					'0' when PA = x"80" and PARD_N = '0' and RAMSEL_N = '1' else 
					'1';
				
	RAM_WE_N <= '1' when ENABLE = '0' else
					'0' when RAMSEL_N = '0' and CPUWR_N = '0' else
					'0' when PA = x"80" and PAWR_N = '0' and RAMSEL_N = '1' else 
					'1';
					
	--debug
	process( CLK, RST_N, WMADD, RAM_Q, DBG_REG )
	begin
		case DBG_REG is
			when x"00" => DBG_DAT_OUT <= WMADD(7 downto 0);
			when x"01" => DBG_DAT_OUT <= WMADD(15 downto 8);
			when x"02" => DBG_DAT_OUT <= WMADD(23 downto 16);
			when x"03" => DBG_DAT_OUT <= x"00";
			when x"80" => DBG_DAT_OUT <= RAM_Q;
			when others => DBG_DAT_OUT <= x"00";
		end case;
		
		if RST_N = '0' then
			DBG_ADDR <= (others => '0');
			DBG_DAT_WRr <= '0';
		elsif rising_edge(CLK) then
			DBG_DAT_WRr <= DBG_DAT_WR;
			if DBG_DAT_WR = '1' and DBG_DAT_WRr = '0' then
				case DBG_REG is
					when x"80" => DBG_ADDR(7 downto 0) <= DBG_DAT_IN;
					when x"81" => DBG_ADDR(15 downto 8) <= DBG_DAT_IN;
					when x"82" => DBG_ADDR(23 downto 16) <= DBG_DAT_IN;
					when others => null;
				end case;
			end if;
		end if;
	end process;

end rtl;

