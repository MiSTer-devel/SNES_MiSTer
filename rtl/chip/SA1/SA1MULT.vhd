library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SA1MULT is
    port (
        dataa   : in  std_logic_vector(15 downto 0);
        datab   : in  std_logic_vector(15 downto 0);
        result  : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of SA1MULT is
begin
    process (dataa, datab)
        variable facta_s : signed(15 downto 0);
        variable factb_s : signed(15 downto 0);
        variable prod_s  : signed(31 downto 0);
    begin
        facta_s := signed(dataa);
        factb_s := signed(datab);
        prod_s := resize(facta_s * factb_s, 32);
        result <= std_logic_vector(prod_s);
    end process;
end architecture;
