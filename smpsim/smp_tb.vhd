library work;
use work.aram.all;
use work.audio.all;

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.textio.all;

-- `timescale 1us/1ns
    
entity smp_tb is
end;

architecture smp_tb of smp_tb is



signal   clk      : std_logic := '0';
signal   reset_n  : std_logic := '0';

signal DSPCLK    : std_logic;
signal RST_N     : std_logic;

signal ARAM_ADDR : std_logic_vector(15 downto 0);
signal ARAM_D    : std_logic_vector(7 downto 0);
signal ARAM_Q    : std_logic_vector(7 downto 0);
signal ARAM_CE_N : std_logic;
signal ARAM_OE_N : std_logic;
signal ARAM_WE_N : std_logic;

-- APU
signal SMP_CE: std_logic;
signal SMP_A : std_logic_vector(15 downto 0);
signal SMP_DO : std_logic_vector(7 downto 0);
signal SMP_DI : std_logic_vector(7 downto 0);
signal SMP_WE : std_logic;
signal SMP_CPU_DO : std_logic_vector(7 downto 0);
signal SMP_CPU_DI : std_logic_vector(7 downto 0);
signal SMP_EN : std_logic := '1';

signal INT_SYSCLKF_CE: std_logic;
signal INT_PA : std_logic_vector(7 downto 0);
signal INT_PARD_N : std_logic := '1';
signal INT_PAWR_N : std_logic := '1';

signal AUDIO_L : std_logic_vector(15 downto 0);
signal AUDIO_R : std_logic_vector(15 downto 0);

signal SMP_DBG_REG_IN : std_logic_vector(7 downto 0);
signal SMP_DBG_REG : std_logic_vector(7 downto 0);
signal SMP_DBG_DAT_IN : std_logic_vector(7 downto 0);
signal SPC700_DAT_WR : std_logic := '0';
signal SMP_DAT_WR : std_logic := '0';

signal DSP_DBG_REG : std_logic_vector(7 downto 0);
signal DSP_DBG_DAT_IN : std_logic_vector(7 downto 0);
signal DSP_DBG_WR : std_logic := '0';
signal ENABLE : std_logic := '0';
signal PAL : std_logic := '0';

signal LRCK : std_logic;
signal BCK  : std_logic;
signal SDAT : std_logic;
signal SND_RDY : std_logic;

begin

        SMP_DBG_REG_IN <= "0000" & SMP_DBG_REG(3 downto 0);
        SPC700_DAT_WR <= not ENABLE and not SMP_DBG_REG(4);
        SMP_DAT_WR <= not ENABLE and SMP_DBG_REG(4);

        -- SMP
        SMP : entity work.SMP
        port map(
                CLK             => DSPCLK,
                RST_N           => RST_N,
                CE              => SMP_CE,
                ENABLE          => SMP_EN,
                SYSCLKF_CE      => INT_SYSCLKF_CE,

                A               => SMP_A,
                DI              => SMP_DI,
                DO              => SMP_DO,
                WE              => SMP_WE,

                PA              => INT_PA(1 downto 0),
                PARD_N          => INT_PARD_N,
                PAWR_N          => INT_PAWR_N,
                CPU_DI          => SMP_CPU_DI,
                CPU_DO          => SMP_CPU_DO,
                CS              => INT_PA(6),
                CS_N            => INT_PA(7),

                DBG_REG         => SMP_DBG_REG_IN,
                DBG_DAT_IN      => SMP_DBG_DAT_IN,
--                DBG_CPU_DAT     => DBG_SPC700_DAT,
--                DBG_SMP_DAT     => DBG_SMP_DAT,
                DBG_CPU_DAT_WR  => SPC700_DAT_WR,
                DBG_SMP_DAT_WR  => SMP_DAT_WR
--                BRK_OUT         => SMP_BRK

        );
        DSP_DBG_WR <= not ENABLE;
        -- DSP 
        DSP: entity work.DSP 
        port map (
                CLK             => DSPCLK,
                RST_N           => RST_N,
                ENABLE          => ENABLE,
                PAL             => PAL,

                SMP_EN          => SMP_EN,
                SMP_A           => SMP_A,
                SMP_DO          => SMP_DO,
                SMP_DI          => SMP_DI,
                SMP_WE          => SMP_WE,
                SMP_CE          => SMP_CE,

                RAM_A           => ARAM_ADDR,
                RAM_D           => ARAM_D,
                RAM_Q           => ARAM_Q,
                RAM_CE_N        => ARAM_CE_N,
                RAM_OE_N        => ARAM_OE_N,
                RAM_WE_N        => ARAM_WE_N,

                LRCK            => LRCK,
                BCK             => BCK,
                SDAT            => SDAT,

                DBG_REG         => DSP_DBG_REG,
                DBG_DAT_IN      => DSP_DBG_DAT_IN,
--                DBG_DAT_OUT => DBG_DSP_DAT,
                DBG_DAT_WR      => DSP_DBG_WR,

                AUDIO_L         => AUDIO_L,
                AUDIO_R         => AUDIO_R,
                SND_RDY         => SND_RDY
);

DSPCLK <= clk;
RST_N <= reset_n;

-- generate a 21mhz clock
  clock : process
  begin
    wait for 2.4 ns; clk  <= not clk;
  end process clock;

  stimulus : process
  begin
    report "start";

    reset_n <= '0';

    wait for 5 ns; reset_n <= '1';
    assert false report "smp out of reset"
        severity note;

    wait;
  end process stimulus;
  
  memory : process (clk)
    variable c : std_logic;
    variable we : std_logic;
    variable a : std_logic_vector(15 downto 0);
    variable q : std_logic_vector(7 downto 0);
    variable d : std_logic_vector(7 downto 0);

    variable dsp_reg_addr : std_logic_vector(6 downto 0);
    variable dsp_reg_q: std_logic_vector(7 downto 0);
    variable spc_reg_addr : std_logic_vector(2 downto 0);
    variable spc_reg_q: std_logic_vector(7 downto 0);
    variable smp_reg_addr : std_logic_vector(3 downto 0);
    variable smp_reg_q: std_logic_vector(7 downto 0);
  begin
    -- wire memory
    c := clk;
    a := ARAM_ADDR;
    we := not (ARAM_CE_N or ARAM_WE_N);
    d := ARAM_D;

    spc_reg_addr := SMP_DBG_REG(2 downto 0);
    smp_reg_addr := SMP_DBG_REG(3 downto 0);
    dsp_reg_addr := DSP_DBG_REG(6 downto 0);
    aram_c(c,we,d,a,q,spc_reg_addr,spc_reg_q,smp_reg_addr,smp_reg_q,dsp_reg_addr,dsp_reg_q);
    
    if (clk = '0' and clk'event) then
      ARAM_Q <= q;
      DSP_DBG_DAT_IN <= dsp_reg_q;
      if SMP_DBG_REG(4) = '0' then
        SMP_DBG_DAT_IN <= spc_reg_q;
      else
        SMP_DBG_DAT_IN <= smp_reg_q;
      end if;
    end if;   
 end process memory;

  initialize : process (clk)
    variable state : std_logic_vector(1 downto 0);
  begin
    if RST_N = '0' then
      SMP_DBG_REG <= (others => '0');
      DSP_DBG_REG <= (others => '0');
      ENABLE <= '0';
      state := "00";
    elsif rising_edge(clk) then
      if ENABLE = '0' then
        case state is
          when "00" =>
            state := "01";
          when "01" =>
            SMP_DBG_REG <= std_logic_vector(unsigned(SMP_DBG_REG) + 1);
            DSP_DBG_REG <= std_logic_vector(unsigned(DSP_DBG_REG) + 1);
            state := "10";
          when "10" =>
            state := "11";
          when "11" =>
            if DSP_DBG_REG(6 downto 0) = "1111111" then
              ENABLE <= '1';
              assert false report "smp enabled" severity note;
            end if;
            state := "00";
          when others => null;
        end case;
      end if;
    end if;
  end process initialize;

  audio : process (clk)
    variable c : std_logic;
    variable rdy : std_logic;
    variable al : std_logic_vector(15 downto 0);
    variable ar : std_logic_vector(15 downto 0);
  begin
    -- wire memory
    c := clk;
    rdy := SND_RDY;
    al := AUDIO_L;
    ar := AUDIO_R;

    audio_c(c,rdy,al,ar);
    
 end process audio;


end smp_tb;
