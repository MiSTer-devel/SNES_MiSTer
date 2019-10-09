library ieee; use ieee.std_logic_1164.all; 

package aram is
  procedure aram_c (     
    clk: in std_logic;
    we: in std_logic;
    din: in std_logic_vector(7 downto 0);
    addr: in std_logic_vector(15 downto 0);
    dout: out std_logic_vector(7 downto 0);

    spc_reg_addr: in std_logic_vector(2 downto 0);
    spc_reg_dout: out std_logic_vector(7 downto 0);

    smp_reg_addr: in std_logic_vector(3 downto 0);
    smp_reg_dout: out std_logic_vector(7 downto 0);

    dsp_reg_addr: in std_logic_vector(6 downto 0);
    dsp_reg_dout: out std_logic_vector(7 downto 0)
  );
  attribute foreign of aram_c :
    procedure is "VHPIDIRECT aram_c";
end aram;

package body aram is
  procedure aram_c (
    clk: in std_logic;
    we: in std_logic;
    din: in std_logic_vector(7 downto 0);
    addr: in std_logic_vector(15 downto 0);
    dout: out std_logic_vector(7 downto 0);

    spc_reg_addr: in std_logic_vector(2 downto 0);
    spc_reg_dout: out std_logic_vector(7 downto 0);

    smp_reg_addr: in std_logic_vector(3 downto 0);
    smp_reg_dout: out std_logic_vector(7 downto 0);

    dsp_reg_addr: in std_logic_vector(6 downto 0);
    dsp_reg_dout: out std_logic_vector(7 downto 0)
  )     is
  begin
    assert false report "VHPI" severity failure;
  end aram_c;
end aram;
