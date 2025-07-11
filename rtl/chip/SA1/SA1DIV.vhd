library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- reference: https://sneslab.net/wiki/SA-1_Hardware_Behavior

entity SA1DIV is
    port (
        numer    : in  std_logic_vector(15 downto 0);
        denom    : in  std_logic_vector(15 downto 0);
        quotient : out std_logic_vector(15 downto 0);
        remain   : out std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of SA1DIV is
begin
    process(numer, denom)
        variable numer_s  : signed(15 downto 0);
        variable denom_u  : unsigned(15 downto 0);
        variable quot_s   : signed(15 downto 0);
        variable remain_u : unsigned(15 downto 0);
    begin
        numer_s := signed(numer);
        denom_u := unsigned(denom);

        if denom_u = 0 then
            if numer_s < 0 then
                quot_s   := to_signed(1, 16);
                remain_u := unsigned(-numer_s);
            else
                quot_s   := to_signed(-1, 16);
                remain_u := unsigned(numer_s);
            end if;
        else
            quot_s   := numer_s / signed(denom_u);
            remain_u := unsigned(numer_s mod signed(denom_u));
        end if;

        quotient <= std_logic_vector(quot_s);
        remain   <= std_logic_vector(remain_u);
    end process;
end architecture;
