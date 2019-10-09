library ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dpram is
        generic (
                addr_width    : integer := 8;
                data_width    : integer := 8;
                mem_init_file : string := " "
        );
        PORT
        (
                clock                   : in  STD_LOGIC;

                address_a       : in  STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
                data_a          : in  STD_LOGIC_VECTOR (data_width-1 DOWNTO 0) := (others => '0');
                enable_a                : in  STD_LOGIC := '1';
                wren_a          : in  STD_LOGIC := '0';
                q_a                     : out STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);
                cs_a        : in  std_logic := '1';

                address_b       : in  STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0) := (others => '0');
                data_b          : in  STD_LOGIC_VECTOR (data_width-1 DOWNTO 0) := (others => '0');
                enable_b                : in  STD_LOGIC := '1';
                wren_b          : in  STD_LOGIC := '0';
                q_b                     : out STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);
                cs_b        : in  std_logic := '1'
        );
end entity;

architecture arch of dpram is

type ram_type is array(natural range ((2**addr_width)-1) downto 0) of std_logic_vector(data_width-1 downto 0);
shared variable ram : ram_type;

begin

-- Port A
process (clock)
begin
	if (clock'event and clock = '1') then
		if enable_a='1' and cs_a='1' then
			if wren_a='1' then
				ram(to_integer(unsigned(address_a))) := data_a;
				q_a <= data_a;
			else
				q_a <= ram(to_integer(unsigned(address_a)));
			end if;
		end if;
	end if;
end process;

-- Port B
process (clock)
begin
	if (clock'event and clock = '1') then
		if enable_b='1' and cs_b='1' then
			if wren_b='1' then
				ram(to_integer(unsigned(address_b))) := data_b;
				q_b <= data_b;
			else
				q_b <= ram(to_integer(unsigned(address_b)));
			end if;
		end if;
	end if;
end process;


end architecture;
