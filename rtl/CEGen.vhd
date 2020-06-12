library ieee;
use ieee.std_logic_1164.all;

entity CEGen is
  port
    (
      CLK   : in std_logic;
      RST_N : in std_logic;

      IN_CLK  : in integer;
      OUT_CLK : in integer;

      CE : out std_logic
      );
end CEGen;

architecture SYN of CEGen is
begin
  process(RST_N, CLK)
    variable CLK_SUM : integer;
  begin
    if RST_N = '0' then
      CLK_SUM := 0;
      CE      <= '0';
    elsif falling_edge(CLK) then
      CE      <= '0';
      CLK_SUM := CLK_SUM + OUT_CLK;
      if CLK_SUM >= IN_CLK then
        CLK_SUM := CLK_SUM - IN_CLK;
        CE      <= '1';
      end if;
    end if;
  end process;
end SYN;
