--------------------------------------------------------------
-- Single port Block RAM
--------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity spram is
  generic (
    addr_width    : integer := 8;
    data_width    : integer := 8;
    mem_init_file : string  := " ";
    mem_name      : string  := "MEM"    -- for InSystem Memory content editor.
    );
  port
    (
      clock   : in  std_logic;
      address : in  std_logic_vector (addr_width-1 downto 0);
      data    : in  std_logic_vector (data_width-1 downto 0) := (others => '0');
      enable  : in  std_logic                                := '1';
      wren    : in  std_logic                                := '0';
      q       : out std_logic_vector (data_width-1 downto 0);
      cs      : in  std_logic                                := '1'
      );
end spram;


architecture SYN of spram is
begin
  spram_sz : work.spram_sz
    generic map(addr_width, data_width, 2**addr_width, mem_init_file, mem_name)
    port map(clock, address, data, enable, wren, q, cs);
end SYN;


--------------------------------------------------------------
-- Single port Block RAM with specific size
--------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity spram_sz is
  generic (
    addr_width    : integer := 8;
    data_width    : integer := 8;
    numwords      : integer := 2**8;
    mem_init_file : string  := " ";
    mem_name      : string  := "MEM"    -- for InSystem Memory content editor.
    );
  port
    (
      clock   : in  std_logic;
      address : in  std_logic_vector (addr_width-1 downto 0);
      data    : in  std_logic_vector (data_width-1 downto 0) := (others => '0');
      enable  : in  std_logic                                := '1';
      wren    : in  std_logic                                := '0';
      q       : out std_logic_vector (data_width-1 downto 0);
      cs      : in  std_logic                                := '1'
      );
end entity;

architecture SYN of spram_sz is
  signal q0 : std_logic_vector((data_width - 1) downto 0);
begin
  q <= q0 when cs = '1' else (others => '1');

  altsyncram_component : altsyncram
    generic map (
      clock_enable_input_a          => "BYPASS",
      clock_enable_output_a         => "BYPASS",
      intended_device_family        => "Cyclone V",
      lpm_hint                      => "ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME="&mem_name,
      lpm_type                      => "altsyncram",
      numwords_a                    => numwords,
      operation_mode                => "SINGLE_PORT",
      outdata_aclr_a                => "NONE",
      outdata_reg_a                 => "UNREGISTERED",
      power_up_uninitialized        => "FALSE",
      read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
      init_file                     => mem_init_file,
      widthad_a                     => addr_width,
      width_a                       => data_width,
      width_byteena_a               => 1
      )
    port map (
      address_a => address,
      clock0    => clock,
      data_a    => data,
      wren_a    => wren and cs,
      q_a       => q0
      );

end SYN;

--------------------------------------------------------------
-- Dual port Block RAM same parameters on both ports
--------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity dpram is
  generic (
    addr_width    : integer := 8;
    data_width    : integer := 8;
    mem_init_file : string  := " "
    );
  port
    (
      clock : in std_logic;

      address_a : in  std_logic_vector (addr_width-1 downto 0);
      data_a    : in  std_logic_vector (data_width-1 downto 0) := (others => '0');
      enable_a  : in  std_logic                                := '1';
      wren_a    : in  std_logic                                := '0';
      q_a       : out std_logic_vector (data_width-1 downto 0);
      cs_a      : in  std_logic                                := '1';

      address_b : in  std_logic_vector (addr_width-1 downto 0) := (others => '0');
      data_b    : in  std_logic_vector (data_width-1 downto 0) := (others => '0');
      enable_b  : in  std_logic                                := '1';
      wren_b    : in  std_logic                                := '0';
      q_b       : out std_logic_vector (data_width-1 downto 0);
      cs_b      : in  std_logic                                := '1'
      );
end entity;


architecture SYN of dpram is
begin
  ram : work.dpram_dif generic map(addr_width, data_width, addr_width, data_width, mem_init_file)
    port map(clock, address_a, data_a, enable_a, wren_a, q_a, cs_a, address_b, data_b, enable_b, wren_b, q_b, cs_b);
end SYN;

--------------------------------------------------------------
-- Dual port Block RAM different parameters on ports
--------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity dpram_dif is
  generic (
    addr_width_a  : integer := 8;
    data_width_a  : integer := 8;
    addr_width_b  : integer := 8;
    data_width_b  : integer := 8;
    mem_init_file : string  := " "
    );
  port
    (
      clock : in std_logic;

      address_a : in  std_logic_vector (addr_width_a-1 downto 0);
      data_a    : in  std_logic_vector (data_width_a-1 downto 0) := (others => '0');
      enable_a  : in  std_logic                                  := '1';
      wren_a    : in  std_logic                                  := '0';
      q_a       : out std_logic_vector (data_width_a-1 downto 0);
      cs_a      : in  std_logic                                  := '1';

      address_b : in  std_logic_vector (addr_width_b-1 downto 0) := (others => '0');
      data_b    : in  std_logic_vector (data_width_b-1 downto 0) := (others => '0');
      enable_b  : in  std_logic                                  := '1';
      wren_b    : in  std_logic                                  := '0';
      q_b       : out std_logic_vector (data_width_b-1 downto 0);
      cs_b      : in  std_logic                                  := '1'
      );
end entity;


architecture SYN of dpram_dif is

  signal q0 : std_logic_vector((data_width_a - 1) downto 0);
  signal q1 : std_logic_vector((data_width_b - 1) downto 0);

begin
  q_a <= q0 when cs_a = '1' else (others => '1');
  q_b <= q1 when cs_b = '1' else (others => '1');

  altsyncram_component : altsyncram
    generic map (
      address_reg_b                 => "CLOCK1",
      clock_enable_input_a          => "NORMAL",
      clock_enable_input_b          => "NORMAL",
      clock_enable_output_a         => "BYPASS",
      clock_enable_output_b         => "BYPASS",
      indata_reg_b                  => "CLOCK1",
      intended_device_family        => "Cyclone V",
      lpm_type                      => "altsyncram",
      numwords_a                    => 2**addr_width_a,
      numwords_b                    => 2**addr_width_b,
      operation_mode                => "BIDIR_DUAL_PORT",
      outdata_aclr_a                => "NONE",
      outdata_aclr_b                => "NONE",
      outdata_reg_a                 => "UNREGISTERED",
      outdata_reg_b                 => "UNREGISTERED",
      power_up_uninitialized        => "FALSE",
      read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
      read_during_write_mode_port_b => "NEW_DATA_NO_NBE_READ",
      init_file                     => mem_init_file,
      widthad_a                     => addr_width_a,
      widthad_b                     => addr_width_b,
      width_a                       => data_width_a,
      width_b                       => data_width_b,
      width_byteena_a               => 1,
      width_byteena_b               => 1,
      wrcontrol_wraddress_reg_b     => "CLOCK1"
      )
    port map (
      address_a => address_a,
      address_b => address_b,
      clock0    => clock,
      clock1    => clock,
      clocken0  => enable_a,
      clocken1  => enable_b,
      data_a    => data_a,
      data_b    => data_b,
      wren_a    => wren_a and cs_a,
      wren_b    => wren_b and cs_b,
      q_a       => q0,
      q_b       => q1
      );

end SYN;


--------------------------------------------------------------
-- Dual port Block RAM different parameters and clocks on ports
--------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity dpram_difclk is
  generic (
    addr_width_a  : integer := 8;
    data_width_a  : integer := 8;
    addr_width_b  : integer := 8;
    data_width_b  : integer := 8;
    mem_init_file : string  := " "
    );
  port
    (
      clock0 : in std_logic;
      clock1 : in std_logic;

      address_a : in  std_logic_vector (addr_width_a-1 downto 0);
      data_a    : in  std_logic_vector (data_width_a-1 downto 0) := (others => '0');
      enable_a  : in  std_logic                                  := '1';
      wren_a    : in  std_logic                                  := '0';
      q_a       : out std_logic_vector (data_width_a-1 downto 0);
      cs_a      : in  std_logic                                  := '1';

      address_b : in  std_logic_vector (addr_width_b-1 downto 0) := (others => '0');
      data_b    : in  std_logic_vector (data_width_b-1 downto 0) := (others => '0');
      enable_b  : in  std_logic                                  := '1';
      wren_b    : in  std_logic                                  := '0';
      q_b       : out std_logic_vector (data_width_b-1 downto 0);
      cs_b      : in  std_logic                                  := '1'
      );
end entity;


architecture SYN of dpram_difclk is

  signal q0 : std_logic_vector((data_width_a - 1) downto 0);
  signal q1 : std_logic_vector((data_width_b - 1) downto 0);

begin
  q_a <= q0 when cs_a = '1' else (others => '1');
  q_b <= q1 when cs_b = '1' else (others => '1');

  altsyncram_component : altsyncram
    generic map (
      address_reg_b                 => "CLOCK1",
      clock_enable_input_a          => "NORMAL",
      clock_enable_input_b          => "NORMAL",
      clock_enable_output_a         => "BYPASS",
      clock_enable_output_b         => "BYPASS",
      indata_reg_b                  => "CLOCK1",
      intended_device_family        => "Cyclone V",
      lpm_type                      => "altsyncram",
      numwords_a                    => 2**addr_width_a,
      numwords_b                    => 2**addr_width_b,
      operation_mode                => "BIDIR_DUAL_PORT",
      outdata_aclr_a                => "NONE",
      outdata_aclr_b                => "NONE",
      outdata_reg_a                 => "UNREGISTERED",
      outdata_reg_b                 => "UNREGISTERED",
      power_up_uninitialized        => "FALSE",
      read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
      read_during_write_mode_port_b => "NEW_DATA_NO_NBE_READ",
      init_file                     => mem_init_file,
      widthad_a                     => addr_width_a,
      widthad_b                     => addr_width_b,
      width_a                       => data_width_a,
      width_b                       => data_width_b,
      width_byteena_a               => 1,
      width_byteena_b               => 1,
      wrcontrol_wraddress_reg_b     => "CLOCK1"
      )
    port map (
      address_a => address_a,
      address_b => address_b,
      clock0    => clock0,
      clock1    => clock1,
      clocken0  => enable_a,
      clocken1  => enable_b,
      data_a    => data_a,
      data_b    => data_b,
      wren_a    => wren_a and cs_a,
      wren_b    => wren_b and cs_b,
      q_a       => q0,
      q_b       => q1
      );

end SYN;
