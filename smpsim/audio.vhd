library ieee; use ieee.std_logic_1164.all; 

package audio is
  procedure audio_c (     
    clk: in std_logic;
    rdy: in std_logic;
    r: in std_logic_vector(15 downto 0);
    l: in std_logic_vector(15 downto 0)
  );
  attribute foreign of audio_c :
    procedure is "VHPIDIRECT audio_c";
end audio;

package body audio is
  procedure audio_c (
    clk: in std_logic;
    rdy: in std_logic;
    r: in std_logic_vector(15 downto 0);
    l: in std_logic_vector(15 downto 0)
  )     is
  begin
    assert false report "VHPI" severity failure;
  end audio_c;
end audio;
