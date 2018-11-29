--------------------------------------------------------------------------------
-- AVALON SCALER
--------------------------------------------------------------------------------
-- TEMLIB 10/2018
--------------------------------------------------------------------------------
-- This code can be used for any purpose, but, if you find any bug, or want to
-- suggest an enhancement, you ought to send a mail to info@temlib.org
--------------------------------------------------------------------------------

-- Features :
--  - Arbitrary output video format
--  - Autodetect input image size or fixed window
--  - Progressive and interleaved frames
--  - Interpolation
--    Upscaling   : Nearest, Bilinear, Bicubic, Polyphase, Sharp Bilinear
--    Downscaling : Nearest, Bilinear
--  - Avalon bus interface with 128 or 64 bits DATA
--  - Optional triple buffering
--  - 

-- AFAIRE:
--  - Configurable colour depth
--  - 64bits/32 bits Avalon
--  - Sync. pol. detect
--  - Border colour
--  - run/stop
--  - better rounding (linear)
--  - Downscaling
--  - 

--------------------------------------------
-- 4 clock domains
--  i_xxx    : Input video
--  o_xxx    : Output video
--  avl_xxx  : Avalon memory bus
--  poly_xxx : Polyphase filters memory

--------------------------------------------
-- Mode 24bits

-- 5 pixels = 120 bits = 2 x 64bits
-- Burst 32 x 64bits  = 80 pixels = 256 octets
-- Burst 16 x 128bits

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

-- MODE[3]
-- 0 : Direct
-- 1 : Triple buffering

-- MODE[2:0]
-- 000 : Nearest
-- 001 : Bilinear
-- 010 : Sharp Bilinear
-- 011 : Bicubic
-- 100 : Polyphase 1.
-- 101 : Polyphase 2.
-- 110 : Polyphase 3
-- 111 : TEST

-- MASK    : Enable / Disable selected interpoler (0)=Nearest (1)=Bilinear, ...
-- RAMBASE : RAM base address for framebuffer
-- RAMSIZE : Maximum RAM size for one image. (needs x3 if triple-buffering)
-- RO      : True = Read Only. Another block updates the framebuffer
-- INTER   : True=Autodetect interleaved video False=Force progressive scan
-- FRAC    : Fractional bits, subpixel resolution
-- NPOLY   : Number of polyphase filters
-- FORMAT  : TBD
-- N_DW    : Avalon data bus width
-- N_AW    : Avalon address bus width
-- N_BURST : Burst size in bytes. Power of two.
-- OHRES   : Max. output resolution.

ENTITY ascal IS
  GENERIC (
    MASK    : unsigned(0 TO 7) :=x"FF";
    RAMBASE : unsigned(31 DOWNTO 0);
    RO      : boolean := false;
    INTER   : boolean := true;
    FRAC    : natural RANGE 4 TO 6 :=4;
    NPOLY   : natural RANGE 0 TO 2 :=2;
    FORMAT  : natural RANGE 1 TO 8 :=8;
    OHRES   : natural RANGE 1 TO 4096 := 2048;
    N_DW    : natural RANGE 32 TO 128 := 128;
    N_AW    : natural RANGE 8 TO 32 := 32;
    N_BURST : natural := 256 -- 256 bytes per burst
    );
  PORT (
    ------------------------------------
    -- Input video
    i_r   : IN  unsigned(7 DOWNTO 0);
    i_g   : IN  unsigned(7 DOWNTO 0);
    i_b   : IN  unsigned(7 DOWNTO 0);
    i_hs  : IN  std_logic; -- Horizontal sync
    i_vs  : IN  std_logic; -- Vertical sync
    i_fl  : IN  std_logic; -- Interlaced field
    i_de  : IN  std_logic;
    i_ce  : IN  std_logic;
    i_clk : IN  std_logic; -- Input clock

    ------------------------------------
    -- Output video
    o_r   : OUT unsigned(7 DOWNTO 0);
    o_g   : OUT unsigned(7 DOWNTO 0);
    o_b   : OUT unsigned(7 DOWNTO 0);
    o_hs  : OUT std_logic; -- H sychro
    o_vs  : OUT std_logic; -- V sychro
    o_de  : OUT std_logic; -- Display Enable
    o_ce  : IN  std_logic; -- Clock Enable
    o_clk : IN  std_logic; -- Output clock

    ------------------------------------
    -- Input video parameters
    iauto : IN std_logic; -- 1=Autodetect image size 0=Choose window
    himin : IN natural RANGE 0 TO 4095;
    himax : IN natural RANGE 0 TO 4095;
    vimin : IN natural RANGE 0 TO 4095;
    vimax : IN natural RANGE 0 TO 4095;
    
    -- Output video parameters
    run   : IN std_logic;
    mode  : IN unsigned(3 DOWNTO 0);
    -- SYNC  |________________________/"""""""""\_______|
    -- DE    |""""""""""""""""""\_______________________|
    -- RGB   |    <#IMAGE#>     ^HDISP                  |
    --            ^HMIN   ^HMAX       ^HSSTART  ^HSSEND ^HTOTAL
    htotal  : IN natural RANGE 0 TO 4095;
    hsstart : IN natural RANGE 0 TO 4095;
    hsend   : IN natural RANGE 0 TO 4095;
    hdisp   : IN natural RANGE 0 TO 4095;
    hmin    : IN natural RANGE 0 TO 4095;
    hmax    : IN natural RANGE 0 TO 4095;
    vtotal  : IN natural RANGE 0 TO 4095;
    vsstart : IN natural RANGE 0 TO 4095;
    vsend   : IN natural RANGE 0 TO 4095;
    vdisp   : IN natural RANGE 0 TO 4095;
    vmin    : IN natural RANGE 0 TO 4095;
    vmax    : IN natural RANGE 0 TO 4095;
    
    ------------------------------------
    -- Polyphase filter coefficients
    poly_clk : IN std_logic;
    poly_dw  : IN unsigned(8 DOWNTO 0);
    poly_a   : IN unsigned(NPOLY+FRAC+2 DOWNTO 0);
    poly_wr  : IN std_logic;
    -- Order :
    --   [Filter 0] [Filter 1]
    --   [Horizontal] [Vertical]
    --   [0]...[2**FRAC-1]
    --   [-1][0][1][2]
    
    ------------------------------------
    -- Avalon
    avl_clk            : IN    std_logic; -- Avalon clock
    avl_waitrequest    : IN    std_logic;
    avl_readdata       : IN    std_logic_vector(N_DW-1 DOWNTO 0);
    avl_readdatavalid  : IN    std_logic;
    avl_burstcount     : OUT   std_logic_vector(7 DOWNTO 0);
    avl_writedata      : OUT   std_logic_vector(N_DW-1 DOWNTO 0);
    avl_address        : OUT   std_logic_vector(N_AW-1 DOWNTO 0);
    avl_write          : OUT   std_logic;
    avl_read           : OUT   std_logic;
    avl_byteenable     : OUT   std_logic_vector(N_DW/8-1 DOWNTO 0);

    ------------------------------------
    reset_na           : IN    std_logic
    );

BEGIN
  ASSERT N_DW=32 OR N_DW=64 OR N_DW=128 REPORT "DW" SEVERITY failure;
  
END ENTITY ascal;

--##############################################################################

ARCHITECTURE rtl OF ascal IS
  
  ----------------------------------------------------------
  FUNCTION ilog2 (CONSTANT v : natural) RETURN natural IS
    VARIABLE r : natural := 1;
    VARIABLE n : natural := 0;
  BEGIN
    WHILE v>r LOOP
      n:=n+1;
      r:=r*2;
    END LOOP;
    RETURN n;
  END FUNCTION ilog2;
  FUNCTION to_std_logic (a : boolean) RETURN std_logic IS
  BEGIN
    IF a THEN RETURN '1';
         ELSE RETURN '0';
    END IF;
  END FUNCTION to_std_logic;
  
  ----------------------------------------------------------
  CONSTANT NB_BURST : natural :=ilog2(N_BURST);
  CONSTANT NB_LA : natural :=ilog2(N_DW/8); -- Low address bits
  CONSTANT BLEN : natural :=N_BURST / N_DW * 8; -- Burst length
  CONSTANT NP : natural :=24;
  
  ----------------------------------------------------------
  SIGNAL bg_col : unsigned(23 DOWNTO 0); -- Background colour
  
  ----------------------------------------------------------
  -- Input image
  -- IHSIZE=IHMAX-IHMIN
  SIGNAL i_run : std_logic;
  SIGNAL i_frame : std_logic;
  SIGNAL i_hsize,i_hmin,i_hmax,i_hcpt : natural RANGE 0 TO 4095;
  SIGNAL i_chmin,i_chmax,i_cvmin,i_cvmax : natural RANGE 0 TO 4095;
  SIGNAL i_vsize,i_vmin,i_vmax,i_vmaxc,i_vcpt : natural RANGE 0 TO 4095;
  SIGNAL i_vminset : std_logic;
  SIGNAL i_iauto : std_logic;
  SIGNAL i_ven : std_logic;
  SIGNAL i_wr : std_logic;
  SIGNAL i_rgb : unsigned(23 DOWNTO 0);
  SIGNAL i_de_pre,i_hs_pre,i_vs_pre,i_fl_pre : std_logic;
  SIGNAL i_inter : natural RANGE 0 TO 4;
  SIGNAL i_write,i_walt : std_logic;
  SIGNAL i_push : std_logic;
  SIGNAL i_hburst,i_hbcpt : natural RANGE 0 TO 31;
  SIGNAL i_shift : unsigned(N_DW-1 DOWNTO 0) := (others => '0');
  SIGNAL i_acpt : natural RANGE 0 TO 7;
  TYPE arr_dw IS  ARRAY (natural RANGE <>) OF unsigned(N_DW-1 DOWNTO 0);
  SIGNAL i_dpram,o_dpram : arr_dw(0 TO BLEN*2-1);
  ATTRIBUTE ramstyle : string;
  ATTRIBUTE ramstyle OF i_dpram : SIGNAL IS "no_rw_check";
  ATTRIBUTE ramstyle OF o_dpram : SIGNAL IS "no_rw_check";

  SIGNAL i_wad,i_wad_pre : natural RANGE  0 TO BLEN*2-1;
  SIGNAL i_dw : unsigned(N_DW-1 DOWNTO 0);
  SIGNAL i_adrs,i_adrsi : unsigned(31 DOWNTO 0); -- Avalon address
  SIGNAL i_reset_na : std_logic;
  ----------------------------------------------------------
  -- Avalon
  TYPE type_avl_state IS (sIDLE,sWRITE,sREAD);
  SIGNAL avl_state : type_avl_state;
  SIGNAL avl_mode : unsigned(3 DOWNTO 0);
  SIGNAL avl_frame : std_logic;
  SIGNAL avl_write_i,avl_write_sync,avl_write_sync2 : std_logic;
  SIGNAL avl_read_i,avl_read_sync,avl_read_sync2 : std_logic;
  SIGNAL avl_read_pulse,avl_write_pulse : std_logic;
  SIGNAL avl_i_vs,avl_i_vs_sync : std_logic;
  SIGNAL avl_o_vs,avl_o_vs_sync : std_logic;
  SIGNAL avl_reading : std_logic;
  SIGNAL avl_read_sr,avl_write_sr,avl_read_clr,avl_write_clr : std_logic;
  SIGNAL avl_rad,avl_rad_c,avl_wad : natural RANGE 0 TO 2*BLEN-1;
  SIGNAL avl_walt : std_logic;
  SIGNAL avl_dw,avl_dr : unsigned(N_DW-1 DOWNTO 0);
  SIGNAL avl_wr : std_logic;
  SIGNAL avl_readack : std_logic;
  SIGNAL avl_radrs,avl_wadrs,avl_size : unsigned(31 DOWNTO 0);

  SIGNAL avl_i_buf,avl_o_buf : natural RANGE 0 TO 2;
  SIGNAL avl_i_offset,avl_o_offset : unsigned(31 DOWNTO 0);
  SIGNAL avl_bufup : std_logic;
  SIGNAL avl_reset_na : std_logic;
  
  FUNCTION buf_next(a,b : natural RANGE 0 TO 2) RETURN natural IS
  BEGIN
    IF (a=0 AND b=1) OR (a=1 AND b=0) THEN RETURN 2; END IF;
    IF (a=1 AND b=2) OR (a=2 AND b=1) THEN RETURN 0; END IF;
    RETURN 1;                              
  END FUNCTION;
  FUNCTION buf_offset(a : unsigned(31 DOWNTO 0);
                      b : natural RANGE 0 TO 2) RETURN unsigned IS
  BEGIN
    IF b=1 THEN RETURN a; END IF;
    IF b=2 THEN RETURN a(30 DOWNTO 0) & '0'; END IF;
    RETURN x"00000000"; 
  END FUNCTION;

  SIGNAL avl_debug_write : natural RANGE 0 TO 255;
  
  ----------------------------------------------------------
  -- Output
  SIGNAL o_run : std_logic;
  SIGNAL o_mode,o_modex : unsigned(3 DOWNTO 0);
  SIGNAL o_htotal,o_hsstart,o_hsend : natural RANGE 0 TO 4095;
  SIGNAL o_hmin,o_hmax,o_hdisp : natural RANGE 0 TO 4095;
  SIGNAL o_vtotal,o_vsstart,o_vsend : natural RANGE 0 TO 4095;
  SIGNAL o_vmin,o_vmax,o_vdisp : natural RANGE 0 TO 4095;
  SIGNAL o_divcpt : natural RANGE 0 TO 36;
  SIGNAL o_divstart : std_logic;
  SIGNAL o_divrun : std_logic;
  TYPE type_o_state IS (sDISP,sHSYNC,sREAD,sWAITREAD);
  SIGNAL o_state : type_o_state;
  SIGNAL o_copy,o_readack,o_readack_sync,o_readack_sync2 : std_logic;
  SIGNAL o_copy1,o_copy2,o_copy3,o_copy4 : std_logic;
  SIGNAL o_adrs : unsigned(31 DOWNTO 0); -- Avalon address
  SIGNAL o_ad : natural RANGE 0 TO 2*BLEN-1;
  SIGNAL o_adturn : std_logic;
  SIGNAL o_dr,o_dr2 : unsigned(N_DW-1 DOWNTO 0);
  SIGNAL o_reset_na : std_logic;

  TYPE arr_pix IS ARRAY (natural RANGE <>) OF unsigned(NP-1 DOWNTO 0);
  SIGNAL o_linem,o_line0,o_line1,o_line2 : arr_pix(0 TO OHRES-1);
  ATTRIBUTE ramstyle OF o_linem : SIGNAL IS "no_rw_check";
  ATTRIBUTE ramstyle OF o_line0 : SIGNAL IS "no_rw_check";
  ATTRIBUTE ramstyle OF o_line1 : SIGNAL IS "no_rw_check";
  ATTRIBUTE ramstyle OF o_line2 : SIGNAL IS "no_rw_check";
  SIGNAL o_wadl,o_radl : natural RANGE 0 TO 4095;
  SIGNAL o_ldw,o_ldrm,o_ldr0,o_ldr1,o_ldr2 : unsigned(NP-1 DOWNTO 0);
  SIGNAL o_wr : unsigned(3 DOWNTO 0);
  SIGNAL o_hcpt,o_vcpt     : natural RANGE 0 TO 4095;
  SIGNAL o_hdelta,o_vdelta : unsigned(23 DOWNTO 0);
  SIGNAL o_ihsize,o_ivsize : natural RANGE 0 TO 4095;
  SIGNAL o_hdivi,o_vdivi   : unsigned(11 DOWNTO 0);
  SIGNAL o_hdivr,o_vdivr   : unsigned(35 DOWNTO 0);
  
  SIGNAL o_hpos,o_hpos_next : unsigned(23 DOWNTO 0);
  SIGNAL o_vpos,o_vpos_pre,o_vini : unsigned(23 DOWNTO 0); -- [23:12].[11.0]
  SIGNAL o_hpos1,o_hpos2 : unsigned(23 DOWNTO 0);
  SIGNAL xxx_vposi : natural RANGE 0 TO 4095;
  SIGNAL o_hs0,o_hs1,o_hs2,o_hs3,o_hs4,o_hs5 : std_logic;
  SIGNAL o_hsp : natural RANGE 0 TO 4;
  SIGNAL o_vsp,o_vs0,o_vs1,o_vs2,o_vs3,o_vs4,o_vs5 : std_logic;
  SIGNAL o_de0,o_de1,o_de2,o_de3,o_de4,o_de5 : std_logic;
  SIGNAL o_pe1,o_pe2,o_pe3,o_pe4,o_pe5,o_pe0 : std_logic;
  SIGNAL o_read : std_logic;
  SIGNAL o_readlev,o_copylev : natural RANGE 0 TO 2;
  SIGNAL o_hburst,o_hbcpt : natural RANGE 0 TO 31;
  SIGNAL o_fload : natural RANGE 0 TO 4;
  SIGNAL o_acpt : natural RANGE 0 TO 7; -- Alternance pixels FIFO
  SIGNAL o_dshi : natural RANGE 0 TO 3;
  SIGNAL o_alt,o_altp,o_alt1,o_alt2,o_alt3,o_alt4 : unsigned(3 DOWNTO 0);
  SIGNAL o_altv : unsigned(0 TO 11);
  SIGNAL o_primv,o_lastv : unsigned(0 TO 2);
  SIGNAL o_dcpt,o_dcpt1,o_dcpt2,o_dcpt3,o_dcpt4 : natural RANGE 0 TO 4095;
  TYPE type_pix IS RECORD
    r,g,b : unsigned(7 DOWNTO 0); -- 0.8
  END RECORD;
  
  SIGNAL o_hpixm,o_hpix0,o_hpix1,o_hpix2 : type_pix;
  SIGNAL o_hpix01,o_hpix02,o_hpix11,o_hpix12 : type_pix;
  SIGNAL o_hpixm1,o_hpix21 : type_pix;
  SIGNAL o_vpixm2,o_vpix02,o_vpix12,o_vpix22 : type_pix;
  SIGNAL o_vpixm3,o_vpix03,o_vpix13,o_vpix23 : type_pix;
  SIGNAL o_vpix04,o_vpix14 : type_pix;
  
  -----------------------------------------------------------------------------
  FUNCTION altx (a : unsigned(1 DOWNTO 0)) RETURN unsigned IS
  BEGIN
    CASE a IS
      WHEN "00" => RETURN "0001";
      WHEN "01" => RETURN "0010";
      WHEN "10" => RETURN "0100";
      WHEN OTHERS => RETURN "1000";
    END CASE;
  END FUNCTION;     
  -----------------------------------------------------------------------------
  FUNCTION bound(a : unsigned;
                 s : natural) RETURN unsigned IS
  BEGIN
    IF a(a'left)='1' THEN
      RETURN x"00";
    ELSIF a(a'left DOWNTO s)/=0 THEN
      RETURN x"FF";
    ELSE
      RETURN a(s-1 DOWNTO s-8);
    END IF;
  END FUNCTION bound;
  -----------------------------------------------------------------------------
  -- Nearest
  FUNCTION near_frac(f : unsigned(11 DOWNTO 0)) RETURN unsigned IS
    VARIABLE x : unsigned(FRAC-1 DOWNTO 0);
  BEGIN
    x:=(OTHERS =>f(11));
    RETURN x;
  END FUNCTION;
  
  SIGNAL o_h_frac,o_v_frac : unsigned(FRAC-1 DOWNTO 0);
  SIGNAL o_h_bil_pix,o_v_bil_pix : type_pix;
  
  -----------------------------------------------------------------------------
  -- Nearest + Bilinear + Sharp Bilinear
  FUNCTION bil_frac(f : unsigned(11 DOWNTO 0)) RETURN unsigned IS
    VARIABLE x : unsigned(FRAC-1 DOWNTO 0);
  BEGIN
    x:=f(11 DOWNTO 12-FRAC);
    RETURN x;
  END FUNCTION;
  
  FUNCTION bil_calc(f :unsigned(FRAC-1 DOWNTO 0);
                    p0,p1 : type_pix) RETURN type_pix IS
  
    VARIABLE u : unsigned(8+FRAC DOWNTO 0);
    VARIABLE x : type_pix;
    CONSTANT Z : unsigned(FRAC-1 DOWNTO 0):=(OTHERS =>'0');
  BEGIN
    u:=p1.r *  ('0' & f) +
       p0.r * (('1' & Z) - ('0' & f));
    x.r:=bound(u,8+FRAC);
    u:=p1.g *  ('0' & f) +
       p0.g * (('1' & Z) - ('0' & f));
    x.g:=bound(u,8+FRAC);
    u:=p1.b *  ('0' & f) +
       p0.b * (('1' & Z) - ('0' & f));
    x.b:=bound(u,8+FRAC);
    RETURN x;
  END FUNCTION;
  
  -----------------------------------------------------------------------------
  -- Sharp Bilinear
  --  <0.5 : x*x*x*4
  --  >0.5 : 1 - (1-x)*(1-x)*(1-x)*4
  FUNCTION gho_frac(f : unsigned(11 DOWNTO 0)) RETURN unsigned IS
    VARIABLE u : signed(FRAC-1 DOWNTO 0);
    VARIABLE v : signed(3*FRAC-1 DOWNTO 0);
  BEGIN
    IF f(11)='0' THEN
      u:=signed(f(11 DOWNTO 12-FRAC));
    ELSE
      u:=signed(NOT f(11 DOWNTO 12-FRAC));
    END IF;
    
    v:=u*u*u;
    IF f(11)='0' THEN
      RETURN unsigned(v(3*FRAC-3 DOWNTO 2*FRAC-2));
    ELSE
      RETURN unsigned(NOT v(3*FRAC-3 DOWNTO 2*FRAC-2));
    END IF;
  
  END FUNCTION;
  
  -----------------------------------------------------------------------------
  -- Bicubic
  TYPE type_bic_abcd IS RECORD
    a : unsigned(7 DOWNTO 0);  --  0.8
    b : signed(8 DOWNTO 0);  --  0.9
    c : signed(11 DOWNTO 0); -- 3.9
    d : signed(10 DOWNTO 0); -- 2.9
  END RECORD;
  TYPE type_bic_pix_abcd IS RECORD
    r,g,b : type_bic_abcd;
  END RECORD;
  TYPE type_bic_tt IS RECORD -- Intermediate result
    r,g,b : signed(12 DOWNTO 0); -- 4.9
  END RECORD;
  
  SIGNAL o_h_bic_pix,o_v_bic_pix : type_pix;
  SIGNAL o_h_bic_abcd1,o_h_bic_abcd2,o_v_bic_abcd1,o_v_bic_abcd2 : type_bic_pix_abcd;
  SIGNAL o_h_bic_tt2,o_v_bic_tt2 : type_bic_tt;
  
  -- Y = A + B.X + C.X.X + D.X.X.X = A + X.(B + X.(C + X.D))
  -- A = Y(0)                                       0 .. 1    unsigned
  -- B = Y(1)/2 - Y(-1)/2                        -1/2 .. +1/2 signed
  -- C = Y(-1) - 5*Y(0)/2 + 2*Y(1) - Y(2)/2        -3 .. +3   signed
  -- D = -Y(-1)/2 + 3*Y(0)/2 - 3*Y(1)/2 + Y(2)/2   -2 .. +2   signed

  FUNCTION bic_coeff(pm,p0,p1,p2 : unsigned(7 DOWNTO 0)) RETURN type_bic_abcd IS
  BEGIN
    RETURN type_bic_abcd'(
      a=>p0,-- 0.8
      b=>signed(('0' & p1) - ('0' & pm)), -- 0.9
      c=>signed(("000" & pm & '0') - ("00" & p0 & "00") - ("0000" & p0) +
                ("00" & p1 & "00") - ("0000" & p2)), -- 3.9
      d=>signed(("00" & p0 & '0') - ("00" & p1 & '0') - ("000" & p1) +
                ("000" & p0) + ("000" & p2) - ("000" & pm))); -- 2.9
  END FUNCTION;
  FUNCTION bic_coef(pm,p0,p1,p2 : type_pix) RETURN type_bic_pix_abcd IS
  BEGIN
    RETURN type_bic_pix_abcd'(r=>bic_coeff(pm.r,p0.r,p1.r,p2.r),
                              g=>bic_coeff(pm.g,p0.g,p1.g,p2.g),
                              b=>bic_coeff(pm.b,p0.b,p1.b,p2.b));
  END FUNCTION;
  FUNCTION bic_calc1(f : unsigned(11 DOWNTO 0);
                     abcd : type_bic_pix_abcd) RETURN type_bic_tt IS
    VARIABLE u : signed(11+FRAC DOWNTO 0);
    VARIABLE v : signed(12+FRAC DOWNTO 0);
    VARIABLE w : signed(10+FRAC DOWNTO 0);
    VARIABLE x : type_bic_tt;
    CONSTANT Z : signed(FRAC-1 DOWNTO 0):=(OTHERS =>'0');
  BEGIN
    -- T= X.(X.D+C)
    u:=abcd.r.d * signed('0' & f(11 DOWNTO 12-FRAC)); -- 2.9 * 1.FRAC = 3.(9+FRAC) -> 2.(9+FRAC)
    v:=(u(10+FRAC) & u(10+FRAC) & u(10+FRAC DOWNTO 0)) + (abcd.r.c(11) & abcd.r.c & Z); -- 4.15
    -- 4.6 * 1.FRAC = 5.(6+FRAC) -> 4.(6+FRAC)
    w:=v(12+FRAC DOWNTO 3+FRAC) * signed('0' & f(11 DOWNTO 12-FRAC)); -- 5.12 -> 4.12
    x.r:=w(9+FRAC DOWNTO FRAC-3); -- 4.9

    u:=abcd.g.d * signed('0' & f(11 DOWNTO 12-FRAC)); -- 2.9 * 1.FRAC = 3.(9+FRAC) -> 2.(9+FRAC)
    v:=(u(10+FRAC) & u(10+FRAC) & u(10+FRAC DOWNTO 0)) + (abcd.g.c(11) & abcd.g.c & Z); -- 4.15
    -- 4.6 * 1.FRAC = 5.(6+FRAC) -> 4.(6+FRAC)
    w:=v(12+FRAC DOWNTO 3+FRAC) * signed('0' & f(11 DOWNTO 12-FRAC)); -- 5.12 -> 4.12
    x.g:=w(9+FRAC DOWNTO FRAC-3); -- 4.9

    u:=abcd.b.d * signed('0' & f(11 DOWNTO 12-FRAC)); -- 2.9 * 1.FRAC = 3.(9+FRAC) -> 2.(9+FRAC)
    v:=(u(10+FRAC) & u(10+FRAC) & u(10+FRAC DOWNTO 0)) + (abcd.b.c(11) & abcd.b.c & Z); -- 4.15
    -- 4.6 * 1.FRAC = 5.(6+FRAC) -> 4.(6+FRAC)
    w:=v(12+FRAC DOWNTO 3+FRAC) * signed('0' & f(11 DOWNTO 12-FRAC)); -- 5.12 -> 4.12
    x.b:=w(9+FRAC DOWNTO FRAC-3); -- 4.9

    RETURN x;
  END FUNCTION;
  
  FUNCTION bic_calc2(f :unsigned(11 DOWNTO 0);
                    t : type_bic_tt;
                    abcd : type_bic_pix_abcd) RETURN type_pix IS
    VARIABLE u : signed(12 DOWNTO 0); -- 4.9
    VARIABLE v : signed(13+FRAC DOWNTO 0); -- 5.(9+FRAC)
    VARIABLE x : type_pix;
    CONSTANT Z : signed(FRAC-1 DOWNTO 0):=(OTHERS =>'0');
  BEGIN
    -- Y = A + X.(B+T)
    u:=t.r +
        (abcd.r.b(8) & abcd.r.b(8) & abcd.r.b(8) & abcd.r.b(8) & abcd.r.b);
    v:=signed('0' & f(11 DOWNTO 12-FRAC))*u +("000" & signed(abcd.r.a) & '0' & Z);
    x.r:=bound(unsigned(v),9+FRAC);
    
    u:=t.g +
        (abcd.g.b(8) & abcd.g.b(8) & abcd.g.b(8) & abcd.g.b(8) & abcd.g.b);
    v:=signed('0' & f(11 DOWNTO 12-FRAC))*u +("000" & signed(abcd.g.a) & '0' & Z);
    x.g:=bound(unsigned(v),9+FRAC);
    
    u:=t.b +
        (abcd.b.b(8) & abcd.b.b(8) & abcd.b.b(8) & abcd.b.b(8) & abcd.b.b);
    v:=signed('0' & f(11 DOWNTO 12-FRAC))*u +("000" & signed(abcd.b.a) & '0' & Z);
    x.b:=bound(unsigned(v),9+FRAC);
    RETURN x;
  END FUNCTION;            
  -----------------------------------------------------------------------------
  -- Polyphase
  
  TYPE arr_uv36 IS ARRAY (natural RANGE <>) OF unsigned(35 DOWNTO 0); -- 9/9/9/9
  TYPE arr_integer IS ARRAY (natural RANGE <>) OF integer;
  CONSTANT POLY16_A : arr_integer := (
    -24,-20,-16,-11,-6,-1,2,5,6,6,5,4,2,1,0,0,
    176,174,169,160,147,129,109,84,58,22,3,-12,-20,-25,-26,-25,
    -24,-26,-26,-23,-16,-4,11,32,58,96,119,140,154,165,172,175,
    0,0,1,2,3,4,6,7,6,4,1,-4,-8,-13,-18,-22);
  
  CONSTANT POLY16_B : arr_integer := (
    0,-4,-8,-10,-11,-11,-10,-9,-8,-6,-4,-3,-2,-1,0,0,
    127,126,124,119,111,103,93,82,72,56,45,35,25,17,9,3,
    0,6,13,20,30,40,50,61,72,88,98,107,115,121,125,127,
    0,0,-1,-1,-2,-4,-5,-6,-8,-10,-11,-11,-10,-9,-6,-2);

  CONSTANT POLY32_A : arr_integer := (
    -24,-22,-20,-18,-16,-13,-11,-8,-6,-3,-1,0,2,3,5,5,6,6,6,5,5,4,4,3,2,1,1,0,0,0,0,0,
    176,175,174,172,169,164,160,153,147,138,129,119,109,96,84,71,58,40,22,12,3,-4,-12,-16,-20,-22,-25,-25,-26,-25,-25,-25,
    -24,-25,-26,-26,-26,-24,-23,-19,-16,-10,-4,4,11,22,32,45,58,77,96,108,119,129,140,147,154,159,165,168,172,173,175,175,
    0,0,0,0,1,1,2,2,3,3,4,5,6,7,7,7,6,5,4,3,1,-1,-4,-6,-8,-10,-13,-15,-18,-20,-22,-22);
  
  CONSTANT POLY32_B : arr_integer := (
    0,-2,-4,-6,-8,-9,-10,-10,-11,-11,-11,-10,-10,-9,-9,-8,-8,-7,-6,-5,-4,-3,-3,-2,-2,-1,-1,0,0,0,0,0,
    128,127,126,125,124,121,119,115,111,107,103,98,93,87,82,77,72,64,56,50,45,40,35,30,25,21,17,13,9,6,3,3,
    0,3,6,9,13,17,20,25,30,35,40,45,50,55,61,66,72,80,88,93,98,102,107,111,115,118,121,123,125,126,127,127,
    0,0,0,0,-1,-1,-1,-2,-2,-3,-4,-5,-5,-5,-6,-7,-8,-9,-10,-10,-11,-11,-11,-11,-10,-10,-9,-8,-6,-4,-2,-2);
  
  FUNCTION gen_poly(n : natural) RETURN arr_uv36 IS
    VARIABLE p16 : arr_integer(0 TO 4*16-1);
    VARIABLE p32 : arr_integer(0 TO 4*32-1);
    VARIABLE m : arr_uv36(0 TO 2**FRAC-1) :=(OTHERS =>x"000000000");
  BEGIN
    IF FRAC=4 THEN
      IF n=0 THEN p16:=POLY16_A; ELSE p16:=POLY16_B; END IF;
      FOR i IN 0 TO 15 LOOP
        m(i):=unsigned(to_signed(p16(i),9) & to_signed(p16(i+16),9) &
                       to_signed(p16(i+32),9) & to_signed(p16(i+48),9));
      END LOOP;
    ELSIF FRAC=5 THEN
      IF n=0 THEN p32:=POLY32_A; ELSE p32:=POLY32_B; END IF;
      FOR i IN 0 TO 31 LOOP
        m(i):=unsigned(to_signed(p32(i),9) & to_signed(p32(i+32),9) &
                       to_signed(p32(i+64),9) & to_signed(p32(i+96),9));
      END LOOP;
    END IF;
    RETURN m;
  END FUNCTION;

  FUNCTION init_poly RETURN arr_uv36 IS
    VARIABLE p : arr_uv36(0 TO 2**(FRAC+NPOLY)-1);
  BEGIN
    FOR i IN 0 TO 2**NPOLY-1 LOOP
      p(i*2**FRAC TO (i+1)*2**FRAC-1):=gen_poly(i MOD 2);
    END LOOP;
    RETURN p;
  END;
  
  SIGNAL o_h_poly : arr_uv36(0 TO 2**(FRAC+NPOLY)-1):=init_poly;
  SIGNAL o_v_poly : arr_uv36(0 TO 2**(FRAC+NPOLY)-1):=init_poly;
  ATTRIBUTE ramstyle OF o_h_poly : SIGNAL IS "no_rw_check";
  ATTRIBUTE ramstyle OF o_v_poly : SIGNAL IS "no_rw_check";
  SIGNAL o_h_poly_a,o_v_poly_a : integer RANGE 0 TO 2**(FRAC+NPOLY)-1;
  SIGNAL o_h_poly_dr,o_v_poly_dr : unsigned(35 DOWNTO 0);
  SIGNAL o_h_poly_pix,o_v_poly_pix : type_pix;
  SIGNAL poly_h_wr,poly_v_wr : std_logic;
  SIGNAL poly_tdw : unsigned(35 DOWNTO 0);
  SIGNAL poly_a2 : unsigned(FRAC+NPOLY-1 DOWNTO 0);
  
  TYPE type_poly_t IS RECORD
    r0,r1,b0,b1,g0,g1 : signed(17 DOWNTO 0);
  END RECORD;
  SIGNAL o_h_poly_t,o_v_poly_t : type_poly_t;
  
  FUNCTION poly_calc1(fi : unsigned(35 DOWNTO 0);
                     pm,p0,p1,p2 : type_pix) RETURN type_poly_t IS
    VARIABLE t : type_poly_t;
  BEGIN
    -- 2.7 * 1.8 = 3.15 
    t.r0:=(signed(fi(35 DOWNTO 27)) * signed('0' & pm.r) +
           signed(fi(26 DOWNTO 18)) * signed('0' & p0.r));
    t.r1:=(signed(fi(17 DOWNTO  9)) * signed('0' & p1.r) +
           signed(fi( 8 DOWNTO  0)) * signed('0' & p2.r));
    t.g0:=(signed(fi(35 DOWNTO 27)) * signed('0' & pm.g) +
           signed(fi(26 DOWNTO 18)) * signed('0' & p0.g));
    t.g1:=(signed(fi(17 DOWNTO  9)) * signed('0' & p1.g) +
           signed(fi( 8 DOWNTO  0)) * signed('0' & p2.g));
    t.b0:=(signed(fi(35 DOWNTO 27)) * signed('0' & pm.b) +
           signed(fi(26 DOWNTO 18)) * signed('0' & p0.b));
    t.b1:=(signed(fi(17 DOWNTO  9)) * signed('0' & p1.b) +
           signed(fi( 8 DOWNTO  0)) * signed('0' & p2.b));
    RETURN t;
  END FUNCTION;
  
  FUNCTION poly_calc2(pt : type_poly_t) RETURN type_pix IS
    VARIABLE p : type_pix;
    VARIABLE t : signed(17 DOWNTO 0); -- 3.15
  BEGIN
    t:=(pt.r0+pt.r1);
    p.r:=bound(unsigned(t),15);
    t:=(pt.g0+pt.g1);
    p.g:=bound(unsigned(t),15);
    t:=(pt.b0+pt.b1);
    p.b:=bound(unsigned(t),15);
    RETURN p;
  END FUNCTION;
  
  -----------------------------------------------------------------------------
  -- DEBUG

  SIGNAL o_debug_read : integer RANGE 0 TO 255;
  SIGNAL o_debug_set : std_logic;
  SIGNAL o_debug_col : unsigned(7 DOWNTO 0);
  SIGNAL o_debug_vin0 : unsigned(0 TO 32*5-1) :=(OTHERS =>'0');
  SIGNAL o_debug_vin1 : unsigned(0 TO 32*5-1) :=(OTHERS =>'0');
  SIGNAL o_hcpt2 : natural RANGE 0 TO 4095;
  
  FUNCTION CC(i : character) RETURN unsigned IS
  BEGIN
    CASE i IS
      WHEN '0' => RETURN "00000";
      WHEN '1' => RETURN "00001";
      WHEN '2' => RETURN "00010";
      WHEN '3' => RETURN "00011";
      WHEN '4' => RETURN "00100";
      WHEN '5' => RETURN "00101";
      WHEN '6' => RETURN "00110";
      WHEN '7' => RETURN "00111";
      WHEN '8' => RETURN "01000";
      WHEN '9' => RETURN "01001";
      WHEN 'A' => RETURN "01010";
      WHEN 'B' => RETURN "01011";
      WHEN 'C' => RETURN "01100";
      WHEN 'D' => RETURN "01101";
      WHEN 'E' => RETURN "01110";
      WHEN 'F' => RETURN "01111";
      WHEN ' ' => RETURN "10000";
      WHEN '=' => RETURN "10001";
      WHEN '+' => RETURN "10010";
      WHEN '-' => RETURN "10011";
      WHEN '<' => RETURN "10100";
      WHEN '>' => RETURN "10101";
      WHEN '^' => RETURN "10110";
      WHEN 'v' => RETURN "10111";
      WHEN '(' => RETURN "11000";
      WHEN ')' => RETURN "11001";
      WHEN ':' => RETURN "11010";
      WHEN '.' => RETURN "11011";
      WHEN ',' => RETURN "11100";
      WHEN '?' => RETURN "11101";
      WHEN '|' => RETURN "11110";
      WHEN '#' => RETURN "11111";
      WHEN OTHERS => RETURN "10000";
    END CASE;
  END FUNCTION CC;
  FUNCTION CS(s : string) RETURN unsigned IS
    VARIABLE r : unsigned(0 TO s'length*5-1);
    VARIABLE j : natural :=0;
  BEGIN
    FOR i IN s'RANGE LOOP
      r(j TO j+4) :=CC(s(i));
      j:=j+5;
    END LOOP;
    RETURN r;
  END FUNCTION CS;
  FUNCTION CN(v : unsigned) RETURN unsigned IS
    VARIABLE t : unsigned(0 TO v'length-1);
    VARIABLE o : unsigned(0 TO v'length/4*5-1);
  BEGIN
    t:=v;
    FOR i IN 0 TO v'length/4-1 LOOP
      o(i*5 TO i*5+4):='0' & t(i*4 TO i*4+3);
    END LOOP;
    RETURN o;
  END FUNCTION CN;
  
BEGIN

  i_reset_na<='0'   WHEN reset_na='0' ELSE '1' WHEN rising_edge(i_clk);
  o_reset_na<='0'   WHEN reset_na='0' ELSE '1' WHEN rising_edge(o_clk);
  avl_reset_na<='0' WHEN reset_na='0' ELSE '1' WHEN rising_edge(avl_clk);
  
  -----------------------------------------------------------------------------
  -- Input pixels FIFO and shreg
  InAT:PROCESS(i_clk,i_reset_na) IS
  BEGIN
    IF i_reset_na='0' THEN
      i_write<='0';
      
    ELSIF rising_edge(i_clk) THEN
      i_push<='0';
      i_run <= run; -- <ASYNC>
      i_iauto<=iauto; -- <ASYNC> ?

      IF i_ce='1' THEN
        --------------------------------
        i_hs_pre<=i_hs;
        i_vs_pre<=i_vs;
        i_de_pre<=i_de;
        i_fl_pre<=i_fl;

        --------------------------------
        -- Interleaved video
        IF i_fl/=i_fl_pre AND i_inter<4 AND INTER THEN
          i_inter<=i_inter+2;
        ELSIF i_vs='1' AND i_vs_pre='0' AND i_inter>0 THEN
          i_inter<=i_inter-1;
        END IF;

        i_frame<=to_std_logic(i_fl='0' OR NOT INTER OR i_inter=0);
        
        --------------------------------
        IF i_hs='1' THEN
          i_hcpt<=0;
        ELSE
          i_hcpt<=i_hcpt+1;
        END IF;
        
        IF i_vs='1' THEN
          i_vcpt<=0;
          i_adrsi<=(OTHERS =>'0');
          IF i_inter>0 AND i_fl='1' AND INTER THEN
            i_adrsi<=to_unsigned(N_BURST * i_hburst,32);
          END IF;
          i_vminset<='0';
          i_wad_pre<=0;
        END IF;
        
        IF i_hs='1' AND i_hs_pre='0' THEN
          i_vcpt<=i_vcpt+1;
        END IF;
       
        i_ven<=to_std_logic(i_hcpt+1>=i_hmin AND i_hcpt+1<=i_hmax AND
                            i_vcpt>=i_vmin AND i_vcpt<=i_vmax AND
                            i_hs='0' AND i_vs='0');
        
        ----------------------------------------------------
        -- Auto-sizing of the input image
        IF i_de='1' AND i_de_pre='0' THEN
          i_chmin<=i_hcpt+1;
        END IF;
        IF i_de='0' AND i_de_pre='1' THEN
          i_chmax<=i_hcpt;
        END IF;
        
        IF i_de='1' AND i_de_pre='0' AND i_vminset='0' THEN
          i_cvmin<=i_vcpt;
          i_vminset<='1';
        END if;
        IF i_de='1' AND i_de_pre='0' THEN
          i_vmaxc<=i_vcpt;
        END IF;
        IF i_vs='1' THEN
          i_cvmax<=i_vmaxc;
        END IF;
        
        IF i_iauto='1' THEN
          i_hmin<=i_chmin;
          i_hmax<=i_chmax;
          i_vmin<=i_cvmin;
          i_vmax<=i_cvmax;
        ELSE
          -- Forced image
          i_hmin<=himin+i_chmin;
          i_hmax<=himax+i_chmin;
          i_vmin<=vimin+i_cvmin;
          i_vmax<=vimax+i_cvmin;
        END IF;
        
        -- VS   __/""""\_______________________
        -- DE   _________________/"""""""\_____
        -- VCPT   0 0 0 1 2 3 4 5 6 7 8 9 10
        --   VMIN = 6 VMAX=9
        
        -- HS   __/""""\_______________________
        -- DE   _________________/"""""""\_____
        -- HCPT   0 0 0 1 2 3 4 5 6 7 8 9 10
        --   HMIN = 6 HMAX=409
        i_hsize<=(4096+i_hmax-i_hmin) MOD 4096;
        i_vsize<=(4096+i_vmax-i_vmin) MOD 4096;
        
        ----------------------------------------------------
        -- Assemble pixels
        i_rgb<=i_r & i_g & i_b;
        
        CASE i_acpt IS
          WHEN 0 =>
            i_shift(23+24*4 DOWNTO 24*4) <= i_rgb;
          WHEN 1 | 5 =>
            i_shift(23+24*3 DOWNTO 24*3) <= i_rgb;
          WHEN 2 | 6 =>
            i_shift(23+24*2 DOWNTO 24*2) <= i_rgb;
          WHEN 3 | 7 =>
            i_shift(23+24*1 DOWNTO 24*1) <= i_rgb;
          WHEN 4 =>
            i_shift(23+24*0 DOWNTO 24*0) <= i_rgb;
        END CASE;
        
        IF i_ven='1' THEN
          IF i_acpt=4 THEN
            i_acpt<=0;
            i_push<='1';
          ELSE
            i_acpt<=i_acpt+1;
          END IF;
        END IF;
        
        IF i_hs='1' AND i_hs_pre='0' THEN
          i_acpt<=0;
          IF i_acpt/=0 THEN
            i_push<='1';
          END IF;
        END IF;
        
        IF i_hs='0' AND i_hs_pre='1' AND i_vs='0' THEN
          i_hbcpt<=0; -- Bursts per line counter
          IF i_hbcpt>0 THEN
            i_hburst<=i_hbcpt;
          END IF;
          IF i_wad_pre MOD BLEN/=0 THEN
            i_wad_pre<=((i_wad_pre/BLEN+1) MOD 2)*BLEN;
          END IF;
        END IF;
        
      END IF; -- IF i_ce='1'
      
      ------------------------------------------------------
      -- Push pixels to DPRAM
      i_wr<='0';
      IF i_push='1' AND i_run='1' THEN
        i_dw<=i_shift;
        i_wr<='1';
        i_wad_pre<=(i_wad_pre+1) MOD (BLEN*2);
        IF (i_wad MOD BLEN=BLEN-1) OR i_hs='1' THEN
          i_hbcpt<=(i_hbcpt+1) MOD 32;
          i_write<=NOT i_write;
          IF i_wad/BLEN=0 THEN
            i_walt<='0';
          ELSE
            i_walt<='1';
          END IF;
          i_adrs<=i_adrsi;
          i_adrsi<=i_adrsi+N_BURST;
          IF i_hs='1' AND i_fl='1' AND i_inter>0 AND INTER THEN
            i_adrsi<=i_adrsi + N_BURST * (i_hburst + 1);
          END IF;
        END IF;
      END IF;
      
      i_wad<=i_wad_pre;
      
    END IF;
  END PROCESS;

  -----------------------------------------------------------------------------
  -- DPRAM INPUT

  PROCESS (i_clk) IS
  BEGIN
    IF rising_edge(i_clk) THEN
      IF i_wr='1' THEN
        i_dpram(i_wad)<=i_dw;
      END IF;
    END IF;
  END PROCESS;
  
  avl_dr<=i_dpram(avl_rad_c) WHEN rising_edge(avl_clk);
  
  -----------------------------------------------------------------------------
  -- AVALON interface
  Avaloir:PROCESS(avl_clk,avl_reset_na) IS
    VARIABLE debug_write_inc,debug_write_dec : std_logic;
  BEGIN
    IF avl_reset_na='0' THEN
      avl_reading<='0';
      avl_state<=sIDLE;
      avl_write_sr<='0';
      avl_read_sr<='0';
      avl_readack<='0';
      
    ELSIF rising_edge(avl_clk) THEN
      ----------------------------------
      avl_mode<=mode; -- <ASYNC> ?
      avl_write_sync<=i_write; -- <ASYNC>
      avl_write_sync2<=avl_write_sync;
      avl_write_pulse<=avl_write_sync XOR avl_write_sync2;
      debug_write_inc:=avl_write_pulse;
      debug_write_dec:='0';
      avl_wadrs <=i_adrs; -- <ASYNC>
      avl_frame <=i_frame; -- <ASYNC>
      avl_walt  <=i_walt; -- <ASYNC>
      
      ----------------------------------
      avl_read_sync<=o_read; -- <ASYNC>
      avl_read_sync2<=avl_read_sync;
      avl_read_pulse<=avl_read_sync XOR avl_read_sync2;
      
      avl_radrs <=o_adrs; -- <ASYNC>
      --------------------------------------------
      avl_i_vs_sync<=i_vs; -- <ASYNC>
      avl_i_vs<=avl_i_vs_sync;
      avl_o_vs_sync<=o_vs0; -- <ASYNC>
      avl_o_vs<=avl_o_vs_sync;
      
      --------------------------------------------
      -- Triple buffering.
      IF avl_i_vs_sync='1' AND avl_i_vs='0' THEN
        -- Input : Begin of VSYNC pulse
        avl_i_buf<=buf_next(avl_i_buf,avl_o_buf);
        avl_bufup<='1';
        IF avl_frame='1' THEN
          avl_size<=avl_wadrs + N_BURST; -- Total image size
        END IF;
      END IF;
      
      IF avl_o_vs_sync='0' AND avl_o_vs='1' THEN
        -- Output : End of VSYNC pulse
        IF avl_bufup='1' THEN
          avl_o_buf<=buf_next(avl_o_buf,avl_i_buf);
          avl_bufup<='0';
        END IF;
      END IF;
      
      IF avl_mode(3)='0' THEN
        -- Triple buffer disabled
        avl_o_offset<=x"00000000";
        avl_i_offset<=x"00000000";
      ELSE
        avl_o_offset<=buf_offset(avl_size,avl_o_buf);
        avl_i_offset<=buf_offset(avl_size,avl_i_buf);
      END IF;
      
      --------------------------------------------
      avl_dw<=unsigned(avl_readdata);
      avl_read_i<='0';
      avl_write_i<='0';
      
      avl_write_sr<=(avl_write_sr OR avl_write_pulse) AND NOT avl_write_clr;
      avl_read_sr <=(avl_read_sr OR avl_read_pulse) AND NOT avl_read_clr;
      avl_write_clr<='0';
      avl_read_clr <='0';
      
      avl_rad<=avl_rad_c;
      
      --------------------------------------------
      CASE avl_state IS
        WHEN sIDLE =>
          IF avl_o_vs='0' AND avl_o_vs_sync='1' THEN
            avl_wad<=0;
          END IF;
          IF avl_write_sr='1' THEN
            avl_state<=sWRITE;
            avl_write_clr<='1';
            debug_write_dec:='1';
            IF avl_walt='0' THEN
              avl_rad<=0;
            ELSE
              avl_rad<=BLEN;
            END IF;
          ELSIF avl_read_sr='1' AND avl_reading='0' THEN
            IF avl_wad / BLEN = 1 THEN
              avl_wad<=2*BLEN-1;
            ELSE
              avl_wad<=BLEN-1;
            END IF;
            avl_state<=sREAD;
            avl_read_clr<='1';
          END IF;
          
        WHEN sWRITE =>
          avl_address<=std_logic_vector(RAMBASE(N_AW+NB_LA-1 DOWNTO NB_LA) +
            avl_wadrs(N_AW+NB_LA-1 DOWNTO NB_LA) +
            avl_i_offset(N_AW+NB_LA-1 DOWNTO NB_LA));
          avl_write_i<='1';
          IF avl_write_i='1' AND avl_waitrequest='0' THEN
            IF (avl_rad MOD BLEN)=BLEN-1 THEN
              avl_write_i<='0';
              avl_state<=sIDLE;
            END IF;
          END IF;
          
        WHEN sREAD =>
          avl_address<=std_logic_vector(RAMBASE(N_AW+NB_LA-1 DOWNTO NB_LA) +
            avl_radrs(N_AW+NB_LA-1 DOWNTO NB_LA) +
            avl_o_offset(N_AW+NB_LA-1 DOWNTO NB_LA));
          avl_read_i<='1';
          avl_reading<='1';
          IF avl_read_i='1' AND avl_waitrequest='0' THEN
            avl_state<=sIDLE;
            avl_read_i<='0';
          END IF;
      END CASE;
      
      --------------------------------------------
      IF debug_write_inc='1' AND debug_write_dec='0' THEN
        avl_debug_write<=avl_debug_write+1;
      ELSIF debug_write_dec='1' AND debug_write_inc='0' THEN
        avl_debug_write<=avl_debug_write-1;
      END IF;
      
      --------------------------------------------
      -- Pipelined data read
      avl_wr<='0';
      IF avl_readdatavalid='1' THEN
        avl_wr<='1';
        avl_wad<=(avl_wad+1) MOD (2*BLEN);
        IF (avl_wad MOD BLEN)=BLEN-2 THEN
          avl_reading<='0';
          avl_readack<=NOT avl_readack;
        END IF;
      END IF;
      
      --------------------------------------------
    END IF;
  END PROCESS Avaloir;

  avl_read<=avl_read_i;
  avl_write<=avl_write_i;
  avl_writedata<=std_logic_vector(avl_dr);
  avl_burstcount<=std_logic_vector(to_unsigned(BLEN,8));
  avl_byteenable<=(OTHERS =>'1');
  
  avl_rad_c<=(avl_rad+1) MOD (2*BLEN)
              WHEN avl_write_i='1' AND avl_waitrequest='0' ELSE avl_rad;
  
  -----------------------------------------------------------------------------
  -- DPRAM OUTPUT
  PROCESS (avl_clk) IS
  BEGIN
    IF rising_edge(avl_clk) THEN
      IF avl_wr='1' THEN
        o_dpram(avl_wad)<=avl_dw;
      END IF;
    END IF;
  END PROCESS;
      
  o_dr<=o_dpram(o_ad) WHEN rising_edge(o_clk);

  -----------------------------------------------------------------------------
  -- Dividers
  o_ihsize<=i_hsize WHEN rising_edge(o_clk); -- <ASYNC>
  o_ivsize<=i_vsize WHEN rising_edge(o_clk); -- <ASYNC>
  
  --------------------------------------
  -- Hdelta = IHsize / (OHmax-OHmin)
  -- Vdelta = IVsize / (OVmax-OVmin)

  -- Division : 12 / 12 --> 12.12
  
  Dividers:PROCESS (o_clk,o_reset_na) IS
  BEGIN
    IF o_reset_na='0' THEN
      o_hdelta<=x"001000"; -- Simu !
      o_vdelta<=x"001000";
      
    ELSIF rising_edge(o_clk) THEN
      o_hdivi<=to_unsigned(o_hmax - o_hmin,12);
      o_vdivi<=to_unsigned(o_vmax - o_vmin,12);
      o_hdivr<=to_unsigned((o_ihsize) * 4096,36);
      o_vdivr<=to_unsigned((o_ivsize) * 4096,36);

      --------------------------------------------
      IF o_divstart='1' THEN
        o_divcpt<=0;
        o_divrun<='1';
        
      ELSIF o_divrun='1' THEN
        ------------------------------------------
        IF o_divcpt=24 THEN
          o_divrun<='0';
          o_hdelta<=o_hdivr(22 DOWNTO 0) & NOT o_hdivr(35);
          o_vdelta<=o_vdivr(22 DOWNTO 0) & NOT o_vdivr(35);
        ELSE
          o_divcpt<=o_divcpt+1;
        END IF;
        
        ------------------------------------------
        IF o_hdivr(35)='0' THEN
          o_hdivr(35 DOWNTO 24)<=o_hdivr(34 DOWNTO 23) - o_hdivi;
        ELSE
          o_hdivr(35 DOWNTO 24)<=o_hdivr(34 DOWNTO 23) + o_hdivi;
        END IF;
        o_hdivr(23 DOWNTO 0)<=o_hdivr(22 DOWNTO 0) & NOT o_hdivr(35);
        
        IF o_vdivr(35)='0' THEN
          o_vdivr(35 DOWNTO 24)<=o_vdivr(34 DOWNTO 23) - o_vdivi;
        ELSE
          o_vdivr(35 DOWNTO 24)<=o_vdivr(34 DOWNTO 23) + o_vdivi;
        END IF;
        o_vdivr(23 DOWNTO 0)<=o_vdivr(22 DOWNTO 0) & NOT o_vdivr(35);
        
        ------------------------------------------
      END IF;
    END IF;
  END PROCESS Dividers;
  
  -----------------------------------------------------------------------------
  Scalaire:PROCESS (o_clk,o_reset_na) IS
    VARIABLE mul_v : unsigned(47 DOWNTO 0);
    VARIABLE lev_inc_v,lev_dec_v : std_logic;
    VARIABLE alt_v : std_logic;
    VARIABLE debug_read_dec,debug_read_inc : std_logic;
    VARIABLE prim_v,last_v : std_logic;
  BEGIN
    IF o_reset_na='0' THEN
      o_copy<='0';
      o_state<=sDISP;
      o_read<='0';
      o_readlev<=0;
      o_copylev<=0;
      
    ELSIF rising_edge(o_clk) THEN
      ------------------------------------------------------
      o_mode   <=mode; -- <ASYNC> ?
      --o_run    <=run; -- <ASYNC> ?
      
      o_htotal <=htotal; -- <ASYNC> ?
      o_hsstart<=hsstart; -- <ASYNC> ?
      o_hsend  <=hsend; -- <ASYNC> ?
      o_hdisp  <=hdisp; -- <ASYNC> ?
      o_hmin   <=hmin; -- <ASYNC> ?
      o_hmax   <=hmax; -- <ASYNC> ?
      
      o_vtotal <=vtotal; -- <ASYNC> ?
      o_vsstart<=vsstart; -- <ASYNC> ?
      o_vsend  <=vsend; -- <ASYNC> ?
      o_vdisp  <=vdisp; -- <ASYNC> ?
      o_vmin   <=vmin; -- <ASYNC> ?
      o_vmax   <=vmax; -- <ASYNC> ?
      
      o_hburst<=i_hburst; -- <ASYNC> Bursts per line

      ------------------------------------------------------
      -- Test mode
      o_modex<=o_mode;
      IF o_mode(2 DOWNTO 0)="111" THEN
        o_modex(2 DOWNTO 0)<=to_unsigned((o_hcpt/128 + o_vcpt/128) MOD 8,3);
      END IF;
      ------------------------------------------------------
      -- Initial values
      mul_v:=o_vmin * o_vdelta;
      o_vini<=x"000000" - mul_v(47 DOWNTO 24);
      
      ------------------------------------------------------
      -- End DRAM READ
      o_readack_sync<=avl_readack; -- <ASYNC>
      o_readack_sync2<=o_readack_sync;
      o_readack<=o_readack_sync XOR o_readack_sync2;
      debug_read_dec:=o_readack;
      debug_read_inc:='0';
      
      o_divstart<=o_vs1 AND NOT o_vs0;
      
      ------------------------------------------------------
      lev_inc_v:='0';
      lev_dec_v:='0';
      
      -- acpt : Pixel position within current data word
      -- dcpt : Destination image position
      -- hpos : Source image position, fixed point 12.12
      IF o_vs0='1' AND o_vs1='0' THEN
        o_vsp<='1';
      END IF;
      IF o_hs0='1' AND o_hs1='0' THEN
        IF o_hsp<4 THEN
          o_hsp<=o_hsp+1;
        END IF;
      END IF;
      
      CASE o_state IS
          --------------------------------------------------
        WHEN sDISP =>
          IF o_hsp>0 THEN
            o_state<=sHSYNC;
            o_hsp<=o_hsp-1;
          END IF;
          IF o_vsp='1' THEN
            o_fload<=2; -- Force preload 3 lines at top of screen
            o_vsp<='0';
          END IF;
          
          --------------------------------------------------
        WHEN sHSYNC =>
          o_vpos_pre<=o_vpos;
          o_hbcpt<=0; -- Clear burst counter on line
          IF o_vpos(12)/=o_vpos_pre(12) OR o_fload>0 THEN
            o_state<=sREAD;
          ELSE
            o_state<=sDISP;
          END IF;
          
        WHEN sREAD =>
          -- Read a block
          IF o_readlev<2 THEN
            lev_inc_v:='1';
            o_read<=NOT o_read;
            debug_read_inc:='1';
            o_state <=sWAITREAD;
          END IF;
          prim_v:=to_std_logic(o_hbcpt=0);
          last_v:=to_std_logic(o_hbcpt=o_hburst-1);
          
          IF o_fload=2 THEN
            o_adrs<=to_unsigned(o_hbcpt * N_BURST,32);
            -- Update all lines on top border.
            o_altp<="1111";
            
          ELSIF o_fload=1 THEN
            o_adrs<=to_unsigned((o_hburst + o_hbcpt) * N_BURST,32);
            o_altp<="0100";
            
          ELSE
            o_adrs<=to_unsigned((to_integer(
              o_vpos(23 DOWNTO 12)+2) * o_hburst + o_hbcpt) * N_BURST,32);
            o_altp<=altx(o_vpos(13 DOWNTO 12) + 3);
          END IF;
          
        WHEN sWAITREAD =>
          IF o_readack='1' THEN
            o_hbcpt<=o_hbcpt+1;
            IF o_fload>=1 AND o_hbcpt=o_hburst-1 THEN
              o_fload<=o_fload-1;
              o_hbcpt<=0;
              o_state<=sREAD;
            ELSIF o_hbcpt<o_hburst-1 THEN
              -- If more lines to load, or not finshed line, read more
              o_state<=sREAD;
            ELSE
              o_state<=sDISP;
            END IF;
          END IF;
          
          --------------------------------------------------
      END CASE;

      IF debug_read_inc='1' AND debug_read_dec='0' THEN
        o_debug_read<=o_debug_read+1;
      ELSIF debug_read_dec='1' AND debug_read_inc='0' THEN
        o_debug_read<=o_debug_read-1;
      END IF;
      
      ------------------------------------------------------
      -- Copy from buffered memory to pixel lines
      IF o_copy='0' THEN
        IF o_copylev>0 AND o_copy1='0' THEN
          o_copy<='1';
        END IF;
        IF o_vs0='1' AND o_vs1='0' THEN
          o_ad<=BLEN;
        END IF;
        o_acpt<=0;
        o_adturn<='0';
        o_dr2<=o_dr;
        IF o_primv(0)='1' THEN
          -- First memcopy of a horizontal line, carriage return !
          o_hpos<=x"000000";
          o_hpos_next<=o_hdelta;
          o_dcpt<=0;
          o_dshi<=3;
        END IF;
      ELSE
        IF o_dshi=0 THEN
          o_dcpt<=(o_dcpt+1) MOD 4096;
          o_hpos_next<=o_hpos_next+o_hdelta;
          o_hpos<=o_hpos_next;
        ELSE
          -- dshi : Force shift first two pixels of each line
          o_dshi<=o_dshi-1;
        END IF;
        
        -- Pixels -1 / 0 / 1 / 2
        IF o_hpos(12)/=o_hpos_next(12) OR o_dshi>0 THEN
          o_hpixm<=o_hpix0;
          o_hpix0<=o_hpix1;
          o_hpix1<=o_hpix2;
          
          CASE o_acpt IS
            WHEN 0 =>
              o_hpix2<=(r=>o_dr2(23+24*4 DOWNTO 16+24*4),
                        g=>o_dr2(15+24*4 DOWNTO  8+24*4),
                        b=>o_dr2( 7+24*4 DOWNTO    24*4));
            WHEN 1 | 5 =>
              o_hpix2<=(r=>o_dr2(23+24*3 DOWNTO 16+24*3),
                        g=>o_dr2(15+24*3 DOWNTO  8+24*3),
                        b=>o_dr2( 7+24*3 DOWNTO    24*3));
            WHEN 2 | 6 =>
              o_hpix2<=(r=>o_dr2(23+24*2 DOWNTO 16+24*2),
                        g=>o_dr2(15+24*2 DOWNTO  8+24*2),
                        b=>o_dr2( 7+24*2 DOWNTO    24*2));
            WHEN 3 | 7 =>
              o_hpix2<=(r=>o_dr2(23+24*1 DOWNTO 16+24*1),
                        g=>o_dr2(15+24*1 DOWNTO  8+24*1),
                        b=>o_dr2( 7+24*1 DOWNTO    24*1));
            WHEN 4 =>
              o_hpix2<=(r=>o_dr2(23+24*0 DOWNTO 16+24*0),
                        g=>o_dr2(15+24*0 DOWNTO  8+24*0),
                        b=>o_dr2( 7+24*0 DOWNTO    24*0));
          END CASE;
          
          --IF o_adturn='1' AND (o_ad MOD BLEN=0)  THEN
          IF o_adturn='1' AND (((o_ad MOD BLEN=0) AND o_lastv(0)='0') OR
                               ((o_ad MOD BLEN=2) AND o_lastv(0)='1')) THEN
            o_copy<='0';
            lev_dec_v:='1';
            IF o_ad MOD BLEN=2 THEN
              o_ad<=o_ad-2;
            END IF;
          END IF;
          IF o_acpt=3 THEN
            o_ad<=(o_ad+1) MOD (2*BLEN);
          END IF;
          IF o_ad MOD BLEN=4 THEN
            o_adturn<='1';
          END IF;
          IF o_acpt=4 THEN
            o_acpt<=0;
            o_dr2<=o_dr;
          ELSE
            o_acpt<=o_acpt+1;
          END IF;
        END IF;
      END IF;
      
      ------------------------------------------------------
      -- READLEV : Number of ongoing Avalon Reads
      IF lev_dec_v='1'  AND lev_inc_v='0' THEN
        o_readlev<=o_readlev-1;
      ELSIF lev_dec_v='0' AND lev_inc_v='1' THEN
        o_readlev<=o_readlev+1;
      END IF;
      
      -- COPYLEV : Number of ongoing copies to line buffers
      IF lev_dec_v='1'  AND o_readack='0' THEN
        o_copylev<=o_copylev-1;
      ELSIF lev_dec_v='0' AND o_readack='1' THEN
        o_copylev<=o_copylev+1;
      END IF;

      -- FIFOs : First/Last read block from a line
      IF lev_dec_v='1' THEN
        o_primv(0 TO 1)<=o_primv(1 TO 2);
        o_lastv(0 TO 1)<=o_lastv(1 TO 2);
      END IF;
      IF lev_inc_v='1' THEN
        IF o_readlev=0 OR (o_readlev=1 AND lev_dec_v='1') THEN
          o_primv(0)<=prim_v;
          o_lastv(0)<=last_v;
        ELSIF o_readlev=1 AND lev_dec_v='0' THEN
          o_primv(1)<=prim_v;
          o_lastv(1)<=last_v;
        END IF;
        o_primv(2)<=prim_v;
        o_lastv(2)<=last_v;
      END IF;
      
      ------------------------------------------------------
      -- FIFO that stores which line buffer should be updated
      IF lev_dec_v='1' THEN
        o_altv(0 TO 7)<=o_altv(4 TO 11);
      END IF;
      IF o_readack='1' THEN -- push
        IF o_copylev=0 OR (o_copylev=1 AND lev_dec_v='1') THEN
          o_altv(0 TO 3)<=o_altp;
        ELSIF o_copylev=1 AND lev_dec_v='0' THEN
          o_altv(4 TO 7)<=o_altp;
        END IF;
        o_altv(8 TO 11)<=o_altp;
      END IF;
      
      ------------------------------------------------------
    END IF;
  END PROCESS Scalaire;
  
  o_alt<=o_altv(0 TO 3);

  o_h_poly_a<=to_integer(o_modex(0) & o_hpos(11 DOWNTO 12-FRAC));
  o_v_poly_a<=to_integer(o_modex(0) & o_vpos(11 DOWNTO 12-FRAC));

  -----------------------------------------------------------------------------
  -- Polyphase ROMs
  o_h_poly_dr<=o_h_poly(o_h_poly_a) WHEN rising_edge(o_clk);
  o_v_poly_dr<=o_v_poly(o_v_poly_a) WHEN rising_edge(o_clk);
  
  Polikarpov:PROCESS(poly_clk) IS
  BEGIN
    IF rising_edge(poly_clk) THEN
      IF poly_wr='1' THEN
        poly_tdw(8+9*(3-to_integer(poly_a(1 DOWNTO 0))) DOWNTO
                 9*(3-to_integer(poly_a(1 DOWNTO 0))))<=poly_dw;
      END IF;
      
      poly_h_wr<=poly_wr AND NOT poly_a(FRAC+2);
      poly_v_wr<=poly_wr AND poly_a(FRAC+2);
      poly_a2<=poly_a(NPOLY+FRAC+2 DOWNTO FRAC+3) & poly_a(FRAC+1 DOWNTO 2);
      
      IF poly_h_wr='1' THEN
        o_h_poly(to_integer(poly_a2))<=poly_tdw;
      END IF;
      IF poly_v_wr='1' THEN
        o_v_poly(to_integer(poly_a2))<=poly_tdw;
      END IF;
    END IF;
  END PROCESS Polikarpov;
  
  -----------------------------------------------------------------------------
  -- Horizontal Scaler
  HSCAL:PROCESS(o_clk) IS
  BEGIN
    IF rising_edge(o_clk) THEN
      -- Pipeline signals
      o_hpos1<=o_hpos; o_hpos2<=o_hpos1;
      o_alt1 <=o_alt;  o_alt2 <=o_alt1;  o_alt3 <=o_alt2;  --o_alt4 <=o_alt3;
      o_copy1<=o_copy; o_copy2<=o_copy1; o_copy3<=o_copy2; --o_copy4<=o_copy3;
      o_dcpt1<=o_dcpt; o_dcpt2<=o_dcpt1; o_dcpt3<=o_dcpt2; --o_dcpt4<=o_dcpt3;

      o_hpixm1<=o_hpixm;
      o_hpix01<=o_hpix0; o_hpix02<=o_hpix01;
      o_hpix11<=o_hpix1; o_hpix12<=o_hpix11;
      o_hpix21<=o_hpix2;
      
      -- NEAREST / BILINEAR / GHOGAN ---------------------
      -- C2 : Select
      CASE o_modex(1 DOWNTO 0) IS
        WHEN "00" => -- Nearest
          o_h_frac<=near_frac(o_hpos1(11 DOWNTO 0));
        WHEN "01" => -- Bilinear
          o_h_frac<=bil_frac(o_hpos1(11 DOWNTO 0));
        WHEN "10" => -- Sharp Bilinear
          o_h_frac<=gho_frac(o_hpos1(11 DOWNTO 0));
        WHEN OTHERS =>
          o_h_frac<=near_frac(o_hpos1(11 DOWNTO 0));
      END CASE;
      
      -- C3 : Nearest / Bilinear / Sharp Bilinear
      o_h_bil_pix<=bil_calc(o_h_frac,o_hpix02,o_hpix12);
      
      -- BICUBIC -----------------------------------------
      -- C1 : Bicubic coefficients A,B,C,D
      o_h_bic_abcd1<=bic_coef(o_hpixm,o_hpix0,o_hpix1,o_hpix2);
      
      -- C2 : Bicubic calc T = X.(X.D + C)
      o_h_bic_abcd2<=o_h_bic_abcd1;
      o_h_bic_tt2<=bic_calc1(o_hpos1(11 DOWNTO 0),o_h_bic_abcd1);
      
      -- C3 : Bicubic final Y = A + X.(B + T)
      o_h_bic_pix<=bic_calc2(o_hpos2(11 DOWNTO 0),o_h_bic_tt2,o_h_bic_abcd2);
      
      -- POLYPHASE ---------------------------------------
      -- C1 : Read memory
      
      -- C2 : Filter calc
      o_h_poly_t<=poly_calc1(o_h_poly_dr,o_hpixm1,o_hpix01,o_hpix11,o_hpix21);
      
      -- C3 : Bounding
      o_h_poly_pix<=poly_calc2(o_h_poly_t);
      
      -- C4 : Select interpoler --------------------------
      o_wadl<=o_dcpt3;
      o_wr(0)<=o_alt3(0) AND o_copy3;
      o_wr(1)<=o_alt3(1) AND o_copy3;
      o_wr(2)<=o_alt3(2) AND o_copy3;
      o_wr(3)<=o_alt3(3) AND o_copy3;
      
      CASE o_modex(2 DOWNTO 0) IS
        WHEN "000" | "001" | "010" => -- Nearest | Bilinear | Sharp Bilinear
          o_ldw<=o_h_bil_pix.r & o_h_bil_pix.g & o_h_bil_pix.b;
          
        WHEN "011" => -- BiCubic
          o_ldw<=o_h_bic_pix.r & o_h_bic_pix.g & o_h_bic_pix.b;
          
        WHEN OTHERS => -- PolyPhase
          o_ldw<=o_h_poly_pix.r & o_h_poly_pix.g & o_h_poly_pix.b;
          
      END CASE;
      ----------------------------------------------------
    END IF;
  END PROCESS HSCAL;
  
  -----------------------------------------------------------------------------
  -- Line buffers 4 x OHSIZE x (R+G+B)
  OLBUF:PROCESS(o_clk) IS
  BEGIN
    IF rising_edge(o_clk) THEN
      -- WRITES
		if o_wadl < OHRES then
			IF o_wr(0)='1' THEN
			  o_linem(o_wadl)<=o_ldw; -- -1
			END IF;
			IF o_wr(1)='1' THEN
			  o_line0(o_wadl)<=o_ldw; -- 0
			END IF;
			IF o_wr(2)='1' THEN
			  o_line1(o_wadl)<=o_ldw; -- 1
			END IF;
			IF o_wr(3)='1' THEN
			  o_line2(o_wadl)<=o_ldw; -- 2
			END IF;
		end if;
	  
		-- READS
		o_ldrm<=o_linem(o_radl);
		o_ldr0<=o_line0(o_radl);
		o_ldr1<=o_line1(o_radl);
		o_ldr2<=o_line2(o_radl);
    END IF;
  END PROCESS OLBUF;
  
  o_radl<=(o_hcpt-o_hmin+4096) MOD 4096;
  --xxx_vposi<=to_integer(o_vpos(23 DOWNTO 12)); -- Simu!
  
  -----------------------------------------------------------------------------
  -- Output video sweep
  OSWEEP:PROCESS(o_clk) IS
  BEGIN
    IF rising_edge(o_clk) THEN
      IF o_ce='1' THEN
        -- Output pixels count
        IF o_hcpt<o_htotal THEN
          o_hcpt<=o_hcpt+1;
        ELSE
          o_hcpt<=0;
          IF o_vcpt<o_vtotal THEN
            o_vcpt<=o_vcpt+1;
          ELSE
            o_vcpt<=0;
          END IF;
        END IF;
        
        -- Input pixels position
        IF o_hcpt=o_hdisp THEN
          IF o_vcpt<=o_vdisp THEN
            o_vpos<=o_vpos+o_vdelta;
          ELSE
            o_vpos<=o_vini;
          END IF;
        END IF;
        
        o_de0<=to_std_logic(o_hcpt<o_hdisp AND o_vcpt<o_vdisp);
        o_pe0<=to_std_logic(o_hcpt>=o_hmin AND o_hcpt<=o_hmax AND
                            o_vcpt>=o_vmin AND o_vcpt<=o_vmax);
        o_hs0<=to_std_logic(o_hcpt>=o_hsstart AND o_hcpt<o_hsend);
        o_vs0<=to_std_logic(o_vcpt>=o_vsstart AND o_vcpt<o_vsend);
      END IF;
    END IF;
  END PROCESS OSWEEP;
  
  -----------------------------------------------------------------------------
  -- Vertical Scaler
  VSCAL:PROCESS(o_clk) IS
    VARIABLE pixm_v ,pix0_v ,pix1_v ,pix2_v  : type_pix;
    VARIABLE pixtm_v,pixt0_v,pixt1_v,pixt2_v : type_pix;
  BEGIN
    IF rising_edge(o_clk) THEN
      IF o_ce='1' THEN
        -- Pipeline signals
        o_hs1<=o_hs0;  o_hs2<=o_hs1;  o_hs3<=o_hs2;  o_hs4<=o_hs3; o_hs5<=o_hs4;
        o_vs1<=o_vs0;  o_vs2<=o_vs1;  o_vs3<=o_vs2;  o_vs4<=o_vs3; o_vs5<=o_vs4;
        o_de1<=o_de0;  o_de2<=o_de1;  o_de3<=o_de2;  o_de4<=o_de3; o_de5<=o_de4;
        o_pe1<=o_pe0;  o_pe2<=o_pe1;  o_pe3<=o_pe2;  o_pe4<=o_pe3; o_pe5<=o_pe4;
        
        -- CYCLE 1 -----------------------------------------
        -- Read mem
        
        -- CYCLE 2 -----------------------------------------
        -- Lines reordering
        pixm_v:=(r=>o_ldrm(23 DOWNTO 16),
                 g=>o_ldrm(15 DOWNTO 8),b=>o_ldrm(7 DOWNTO 0));
        pix0_v:=(r=>o_ldr0(23 DOWNTO 16),
                 g=>o_ldr0(15 DOWNTO 8),b=>o_ldr0(7 DOWNTO 0));
        pix1_v:=(r=>o_ldr1(23 DOWNTO 16),
                 g=>o_ldr1(15 DOWNTO 8),b=>o_ldr1(7 DOWNTO 0));
        pix2_v:=(r=>o_ldr2(23 DOWNTO 16),
                 g=>o_ldr2(15 DOWNTO 8),b=>o_ldr2(7 DOWNTO 0));
        
        CASE o_vpos(13 DOWNTO 12) IS
          WHEN "00" =>
            pixtm_v:=pixm_v;
            pixt0_v:=pix0_v;
            pixt1_v:=pix1_v;
            pixt2_v:=pix2_v;
          WHEN "01" =>
            pixtm_v:=pix0_v;
            pixt0_v:=pix1_v;
            pixt1_v:=pix2_v;
            pixt2_v:=pixm_v;
          WHEN "10" =>
            pixtm_v:=pix1_v;
            pixt0_v:=pix2_v;
            pixt1_v:=pixm_v;
            pixt2_v:=pix0_v;
          WHEN OTHERS =>
            pixtm_v:=pix2_v;
            pixt0_v:=pixm_v;
            pixt1_v:=pix0_v;
            pixt2_v:=pix1_v;
        END CASE;

        -- Bottom edge
        --IF to_integer(o_vpos(23 DOWNTO 12))>=o_ivsize-2 THEN
        --  pixt2_v:=pixt1_v;
        --ELSIF to_integer(o_vpos(23 DOWNTO 12))>=o_ivsize-3 THEN
        --  pixt1_v:=pixt0_v;
        --  pixt2_v:=pixt0_v;
        --END IF;
        o_vpixm2<=pixtm_v;
        o_vpix02<=pixt0_v;
        o_vpix12<=pixt1_v;
        o_vpix22<=pixt2_v;
          
        -- CYCLE 3 -----------------------------------------
        o_vpixm3<=o_vpixm2;
        o_vpix03<=o_vpix02;  o_vpix04<=o_vpix03;
        o_vpix13<=o_vpix12;  o_vpix14<=o_vpix13;
        o_vpix23<=o_vpix22;
        
        -- NEAREST / BILINEAR / GHOGAN ---------------------
        -- C4 : Select
        CASE o_modex(1 DOWNTO 0) IS
          WHEN "00" => -- Nearest
            o_v_frac<=near_frac(o_vpos(11 DOWNTO 0));
          WHEN "01" => -- Bilinear
            o_v_frac<=bil_frac(o_vpos(11 DOWNTO 0));
          WHEN "10" => -- Sharp Bilinear
            o_v_frac<=gho_frac(o_vpos(11 DOWNTO 0));
          WHEN OTHERS =>
            o_v_frac<=near_frac(o_vpos(11 DOWNTO 0));
        END CASE;
        
        -- C5 : Nearest / Bilinear / Sharp Bilinear
        o_v_bil_pix<=bil_calc(o_v_frac,o_vpix04,o_vpix14);
        
        -- BICUBIC -----------------------------------------
        -- C3 : Bicubic coefficients A,B,C,D
        o_v_bic_abcd1<=bic_coef(o_vpixm2,o_vpix02,o_vpix12,o_vpix22);
        
        -- C4 : Bicubic calc T = X.(X.D + C)
        o_v_bic_abcd2<=o_v_bic_abcd1;
        o_v_bic_tt2<=bic_calc1(o_vpos(11 DOWNTO 0),o_v_bic_abcd1);
        
        -- C5 : Bicubic final Y = A + X.(B + IT)
        o_v_bic_pix<=bic_calc2(o_vpos(11 DOWNTO 0),o_v_bic_tt2,o_v_bic_abcd2);
        
        -- POLYPHASE ---------------------------------------
        -- C3 : Read memory
        
        -- C4 : Filter calc
        o_v_poly_t<=poly_calc1(o_v_poly_dr,
                                o_vpixm3,o_vpix03,o_vpix13,o_vpix23);
        
        -- C5 : Filter calc
        o_v_poly_pix<=poly_calc2(o_v_poly_t);
                            
        -- CYCLE 6 -----------------------------------------
        CASE o_modex(2 DOWNTO 0) IS
          WHEN "000" | "001" | "010" => -- Nearest | Bilinear | Sharp Bilinear
            o_r<=o_v_bil_pix.r;
            o_g<=o_v_bil_pix.g;
            o_b<=o_v_bil_pix.b;
            
          WHEN "011" => -- BiCubic
            o_r<=o_v_bic_pix.r;
            o_g<=o_v_bic_pix.g;
            o_b<=o_v_bic_pix.b;
            
          WHEN OTHERS => -- Polyphase
            o_r<=o_v_poly_pix.r;
            o_g<=o_v_poly_pix.g;
            o_b<=o_v_poly_pix.b;
            
        END CASE;
        
        IF o_pe5='0' THEN
          o_r<=x"00"; -- Border colour
          o_g<=x"00";
          o_b<=x"00";
        END IF;
        IF o_mode(2 DOWNTO 0)="111" AND o_vcpt<2*8 THEN
          o_r<=(OTHERS => o_debug_set);
          o_g<=(OTHERS => o_debug_set);
          o_b<=(OTHERS => o_debug_set);
        END IF;
        o_hs<=o_hs5;
        o_vs<=o_vs5;
        o_de<=o_de5;
        
        ----------------------------------------------------
      END IF;
    END IF;

  END PROCESS VSCAL;
  
  -----------------------------------------------------------------------------
  -- DEBUG
  Debug:PROCESS(o_clk) IS
    TYPE arr_uv8 IS ARRAY (natural RANGE <>) OF unsigned(7 DOWNTO 0);
    CONSTANT chars : arr_uv8 :=(
      x"3E", x"63", x"73", x"7B", x"6F", x"67", x"3E", x"00",  -- 0
      x"0C", x"0E", x"0C", x"0C", x"0C", x"0C", x"3F", x"00",  -- 1
      x"1E", x"33", x"30", x"1C", x"06", x"33", x"3F", x"00",  -- 2
      x"1E", x"33", x"30", x"1C", x"30", x"33", x"1E", x"00",  -- 3
      x"38", x"3C", x"36", x"33", x"7F", x"30", x"78", x"00",  -- 4
      x"3F", x"03", x"1F", x"30", x"30", x"33", x"1E", x"00",  -- 5
      x"1C", x"06", x"03", x"1F", x"33", x"33", x"1E", x"00",  -- 6
      x"3F", x"33", x"30", x"18", x"0C", x"0C", x"0C", x"00",  -- 7
      x"1E", x"33", x"33", x"1E", x"33", x"33", x"1E", x"00",  -- 8
      x"1E", x"33", x"33", x"3E", x"30", x"18", x"0E", x"00",  -- 9
      x"0C", x"1E", x"33", x"33", x"3F", x"33", x"33", x"00",  -- A
      x"3F", x"66", x"66", x"3E", x"66", x"66", x"3F", x"00",  -- B
      x"3C", x"66", x"03", x"03", x"03", x"66", x"3C", x"00",  -- C
      x"1F", x"36", x"66", x"66", x"66", x"36", x"1F", x"00",  -- D
      x"7F", x"46", x"16", x"1E", x"16", x"46", x"7F", x"00",  -- E
      x"7F", x"46", x"16", x"1E", x"16", x"06", x"0F", x"00",  -- F
      x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",  --' ' 10
      x"00", x"00", x"3F", x"00", x"00", x"3F", x"00", x"00",  -- =  11
      x"00", x"0C", x"0C", x"3F", x"0C", x"0C", x"00", x"00",  -- +  12
      x"00", x"00", x"00", x"3F", x"00", x"00", x"00", x"00",  -- -  13
      x"18", x"0C", x"06", x"03", x"06", x"0C", x"18", x"00",  -- <  14
      x"06", x"0C", x"18", x"30", x"18", x"0C", x"06", x"00",  -- >  15
      x"08", x"1C", x"36", x"63", x"41", x"00", x"00", x"00",  -- ^  16
      x"08", x"1C", x"36", x"63", x"41", x"00", x"00", x"00",  -- v  17
      x"18", x"0C", x"06", x"06", x"06", x"0C", x"18", x"00",  -- (  18
      x"06", x"0C", x"18", x"18", x"18", x"0C", x"06", x"00",  -- )  19
      x"00", x"0C", x"0C", x"00", x"00", x"0C", x"0C", x"00",  -- :  1A
      x"00", x"00", x"00", x"00", x"00", x"0C", x"0C", x"00",  -- .  1B
      x"00", x"00", x"00", x"00", x"00", x"0C", x"0C", x"06",  -- ,  1C
      x"1E", x"33", x"30", x"18", x"0C", x"00", x"0C", x"00",  -- ?  1D
      x"18", x"18", x"18", x"00", x"18", x"18", x"18", x"00",  -- |  1E
      x"36", x"36", x"7F", x"36", x"7F", x"36", x"36", x"00"); -- #  1F
    
    VARIABLE vin_v  : unsigned(0 TO 32*5-1);
    VARIABLE char_v : unsigned(4 DOWNTO 0);
  BEGIN
    IF rising_edge(o_clk) THEN
      IF o_ce='1' THEN
        o_hcpt2<=o_hcpt;
        IF (o_vcpt/8) MOD 2=0 THEN
          vin_v:=o_debug_vin0;
        ELSE
          vin_v:=o_debug_vin1;
        END IF;
        IF o_hcpt<32 * 8 AND o_vcpt<2 * 8 THEN
          char_v:=vin_v((o_hcpt/8)*5 TO (o_hcpt/8)*5+4);
        ELSE
          char_v:="10000"; -- " " : Blank character
        END IF;
        
        o_debug_col<=chars(to_integer(char_v)*8+(o_vcpt MOD 8));
        
        IF o_debug_col(o_hcpt2 MOD 8)='1' THEN
          o_debug_set<='1';
        ELSE
          o_debug_set<='0';
        END IF;
      END IF;
    END IF;
  END PROCESS Debug;

  o_debug_vin0<=
    CN(to_unsigned(o_hburst,8)) &
    CC(' ') &
    CN(to_unsigned(o_ihsize,12)) &
    CC(' ') &
    CN(to_unsigned(o_ivsize,12)) &
    CC(' ') &
    CN(to_unsigned(o_hmin,12)) &
    CC(' ') &
    CN(to_unsigned(o_hmax,12)) &
    CC(' ') &
    CN(to_unsigned(o_vmin,12)) &
    CC(' ') &
    CN(to_unsigned(o_vmax,12)) &
    CC(' ') &
    CN(to_unsigned(i_inter,4)) &
    CC(' ') & CN("000" & i_frame) &
    CC(' ') & CC(' ');

  o_debug_vin1<=
    CN(to_unsigned(o_debug_read,8)) & -- 2
    CC(' ') & -- 1
    CN(to_unsigned(avl_debug_write,8)) & -- 2
    CC(' ') & -- 1
    CN(to_unsigned(avl_i_buf,4)) & -- 1
    CC(' ') & -- 1
    CN(to_unsigned(avl_o_buf,4)) & -- 1
    CC(' ') & -- 1
    CN(avl_size) & -- 8
    CC(' ') & -- 1
    CN(o_hdelta) & -- 6
    CC(' ') & -- 1
    CN(o_vdelta); -- 6
    
    
    
  -----------------------------------------------------------------------------  
END ARCHITECTURE rtl;
