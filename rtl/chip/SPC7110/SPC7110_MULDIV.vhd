library ieee;
use ieee.std_logic_1164.all;

library lpm;
use lpm.all;

entity SPC7110_UMULT is
  port
    (
      dataa  : in  std_logic_vector (15 downto 0);
      datab  : in  std_logic_vector (15 downto 0);
      result : out std_logic_vector (31 downto 0)
      );
end SPC7110_UMULT;


architecture SYN of SPC7110_UMULT is

  signal sub_wire0 : std_logic_vector (31 downto 0);



  component lpm_mult
    generic (
      lpm_hint           : string;
      lpm_representation : string;
      lpm_type           : string;
      lpm_widtha         : natural;
      lpm_widthb         : natural;
      lpm_widthp         : natural
      );
    port (
      dataa  : in  std_logic_vector (15 downto 0);
      datab  : in  std_logic_vector (15 downto 0);
      result : out std_logic_vector (31 downto 0)
      );
  end component;

begin
  result <= sub_wire0(31 downto 0);

  lpm_mult_component : lpm_mult
    generic map (
      lpm_hint           => "MAXIMIZE_SPEED=5",
      lpm_representation => "UNSIGNED",
      lpm_type           => "LPM_MULT",
      lpm_widtha         => 16,
      lpm_widthb         => 16,
      lpm_widthp         => 32
      )
    port map (
      dataa  => dataa,
      datab  => datab,
      result => sub_wire0
      );



end SYN;

---------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library lpm;
use lpm.all;

entity SPC7110_SMULT is
  port
    (
      dataa  : in  std_logic_vector (15 downto 0);
      datab  : in  std_logic_vector (15 downto 0);
      result : out std_logic_vector (31 downto 0)
      );
end SPC7110_SMULT;


architecture SYN of SPC7110_SMULT is

  signal sub_wire0 : std_logic_vector (31 downto 0);



  component lpm_mult
    generic (
      lpm_hint           : string;
      lpm_representation : string;
      lpm_type           : string;
      lpm_widtha         : natural;
      lpm_widthb         : natural;
      lpm_widthp         : natural
      );
    port (
      dataa  : in  std_logic_vector (15 downto 0);
      datab  : in  std_logic_vector (15 downto 0);
      result : out std_logic_vector (31 downto 0)
      );
  end component;

begin
  result <= sub_wire0(31 downto 0);

  lpm_mult_component : lpm_mult
    generic map (
      lpm_hint           => "MAXIMIZE_SPEED=5",
      lpm_representation => "SIGNED",
      lpm_type           => "LPM_MULT",
      lpm_widtha         => 16,
      lpm_widthb         => 16,
      lpm_widthp         => 32
      )
    port map (
      dataa  => dataa,
      datab  => datab,
      result => sub_wire0
      );



end SYN;

---------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library lpm;
use lpm.all;

entity SPC7110_UDIV is
  port
    (
      clock    : in  std_logic;
      denom    : in  std_logic_vector (15 downto 0);
      numer    : in  std_logic_vector (31 downto 0);
      quotient : out std_logic_vector (31 downto 0);
      remain   : out std_logic_vector (15 downto 0)
      );
end SPC7110_UDIV;


architecture SYN of SPC7110_UDIV is

  signal sub_wire0 : std_logic_vector (15 downto 0);
  signal sub_wire1 : std_logic_vector (31 downto 0);



  component lpm_divide
    generic (
      lpm_drepresentation : string;
      lpm_hint            : string;
      lpm_nrepresentation : string;
      lpm_pipeline        : natural;
      lpm_type            : string;
      lpm_widthd          : natural;
      lpm_widthn          : natural
      );
    port (
      clock    : in  std_logic;
      remain   : out std_logic_vector (15 downto 0);
      denom    : in  std_logic_vector (15 downto 0);
      numer    : in  std_logic_vector (31 downto 0);
      quotient : out std_logic_vector (31 downto 0)
      );
  end component;

begin
  remain   <= sub_wire0(15 downto 0);
  quotient <= sub_wire1(31 downto 0);

  LPM_DIVIDE_component : LPM_DIVIDE
    generic map (
      lpm_drepresentation => "UNSIGNED",
      lpm_hint            => "LPM_REMAINDERPOSITIVE=TRUE",
      lpm_nrepresentation => "UNSIGNED",
      lpm_pipeline        => 8,
      lpm_type            => "LPM_DIVIDE",
      lpm_widthd          => 16,
      lpm_widthn          => 32
      )
    port map (
      clock    => clock,
      denom    => denom,
      numer    => numer,
      remain   => sub_wire0,
      quotient => sub_wire1
      );



end SYN;

---------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library lpm;
use lpm.all;

entity SPC7110_SDIV is
  port
    (
      clock    : in  std_logic;
      denom    : in  std_logic_vector (15 downto 0);
      numer    : in  std_logic_vector (31 downto 0);
      quotient : out std_logic_vector (31 downto 0);
      remain   : out std_logic_vector (15 downto 0)
      );
end SPC7110_SDIV;


architecture SYN of SPC7110_SDIV is

  signal sub_wire0 : std_logic_vector (15 downto 0);
  signal sub_wire1 : std_logic_vector (31 downto 0);



  component lpm_divide
    generic (
      lpm_drepresentation : string;
      lpm_hint            : string;
      lpm_nrepresentation : string;
      lpm_pipeline        : natural;
      lpm_type            : string;
      lpm_widthd          : natural;
      lpm_widthn          : natural
      );
    port (
      clock    : in  std_logic;
      remain   : out std_logic_vector (15 downto 0);
      denom    : in  std_logic_vector (15 downto 0);
      numer    : in  std_logic_vector (31 downto 0);
      quotient : out std_logic_vector (31 downto 0)
      );
  end component;

begin
  remain   <= sub_wire0(15 downto 0);
  quotient <= sub_wire1(31 downto 0);

  LPM_DIVIDE_component : LPM_DIVIDE
    generic map (
      lpm_drepresentation => "SIGNED",
      lpm_hint            => "LPM_REMAINDERPOSITIVE=TRUE",
      lpm_nrepresentation => "SIGNED",
      lpm_pipeline        => 8,
      lpm_type            => "LPM_DIVIDE",
      lpm_widthd          => 16,
      lpm_widthn          => 32
      )
    port map (
      clock    => clock,
      denom    => denom,
      numer    => numer,
      remain   => sub_wire0,
      quotient => sub_wire1
      );



end SYN;
