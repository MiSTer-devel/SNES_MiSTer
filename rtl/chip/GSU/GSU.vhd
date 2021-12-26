library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library STD;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.GSU_PKG.all;

entity GSU is
	port(
		CLK			: in std_logic;

		RST_N			: in std_logic;
		ENABLE		: in std_logic;
		
		ADDR   		: in std_logic_vector(23 downto 0);
		DI				: in std_logic_vector(7 downto 0);
		DO				: out std_logic_vector(7 downto 0);
		RD_N			: in std_logic;
		WR_N			: in std_logic;

		SYSCLKF_CE	: in std_logic;
		SYSCLKR_CE	: in std_logic;
		
		TURBO			: in std_logic;

		IRQ_N			: out std_logic;
		
		ROM_A   		: out std_logic_vector(20 downto 0);
		ROM_DI		: in std_logic_vector(7 downto 0);
		ROM_RD_N		: out std_logic;							--for MISTer sdram
				
		RAM_A			: out std_logic_vector(16 downto 0);
		RAM_DI		: in std_logic_vector(7 downto 0);
		RAM_DO		: out std_logic_vector(7 downto 0);
		RAM_WE_N		: out std_logic;
		RAM_CE_N		: out std_logic
	);
end GSU;

architecture rtl of GSU is
	
	--CPU Registers
	signal R						: Reg_t;
	signal CBR 					: std_logic_vector(15 downto 0);
	signal PBR 					: std_logic_vector(7 downto 0);
	signal ROMBR 				: std_logic_vector(7 downto 0);
	signal RAMBR 				: std_logic_vector(7 downto 0);
	signal ROMADDR 			: std_logic_vector(15 downto 0);
	signal RAMADDR 			: std_logic_vector(15 downto 0);
	signal ROMDR 				: std_logic_vector(7 downto 0);
	signal RAMDR 				: std_logic_vector(15 downto 0);
	signal BRAMR 				: std_logic_vector(7 downto 0);
	signal SCBR 				: std_logic_vector(7 downto 0);
	signal MS0 					: std_logic;
	signal IRQ_OFF 			: std_logic;
	signal CLS 					: std_logic;
	signal DREG 				: unsigned(3 downto 0);
	signal SREG 				: unsigned(3 downto 0);
	signal FLAG_B 				: std_logic;
	signal FLAG_ALT1 			: std_logic;
	signal FLAG_ALT2 			: std_logic;
	signal FLAG_GO 			: std_logic;
	signal FLAG_R 				: std_logic;
	signal FLAG_IRQ 			: std_logic;
	signal FLAG_Z 				: std_logic;
	signal FLAG_CY 			: std_logic;
	signal FLAG_S 				: std_logic;
	signal FLAG_OV 			: std_logic;
	signal COLR 				: std_logic_vector(7 downto 0);
	signal POR_TRANS 			: std_logic;
	signal POR_DITH 			: std_logic;
	signal POR_HN 				: std_logic;
	signal POR_FH 				: std_logic;
	signal POR_OBJ 			: std_logic;
	signal SCMR_MD 			: std_logic_vector(1 downto 0);
	signal SCMR_HT 			: std_logic_vector(1 downto 0);
	signal RON 					: std_logic;
	signal RAN 					: std_logic;

	--CPU opcode logic
	signal OPS 					: OpcodeAlt_r;
	signal OP 					: Opcode_r;
	signal MC 					: Microcode_r;
	signal OPCODE 				: std_logic_vector(7 downto 0);
	signal OPDATA 				: std_logic_vector(7 downto 0);
	signal OP_N 				: unsigned(3 downto 0);
	signal STATE 				: integer range 0 to 4;
	signal OP_CYCLES 			: unsigned(2 downto 0);
	signal OP_CYCLE_CNT 		: unsigned(2 downto 0);
	signal OP_CYCLE_EN 		: std_logic;
	
	--CPU Core
	signal EN 					: std_logic;
	signal CPU_EN 				: std_logic;
	signal CLK_CE 				: std_logic;
	signal SPEED 				: std_logic;
	signal ALUR 				: std_logic_vector(15 downto 0);
	signal MULR 				: std_logic_vector(15 downto 0);
	signal ALUZ 				: std_logic;
	signal ALUS 				: std_logic;
	signal ALUOV 				: std_logic;
	signal ALUCY 				: std_logic;
	signal REG_LSB 			: std_logic_vector(7 downto 0);
	signal DST_REG 			: unsigned(3 downto 0);
	signal R14_CHANGE 		: std_logic;
	signal ROMST 				: ROMState_t;
	signal RAMST 				: RAMState_t;
	signal ROM_FETCH_EN 		: std_logic;
	signal RAM_FETCH_EN 		: std_logic;
	signal CACHE_FETCH_EN 	: std_logic;
	signal ROM_CACHE_EN 		: std_logic;
	signal RAM_CACHE_EN 		: std_logic;
	signal ROM_LOAD_EN 		: std_logic;
	signal RAM_LOAD_EN 		: std_logic;
	signal ROM_ACCESS_CNT 	: unsigned(2 downto 0);
	signal RAM_ACCESS_CNT 	: unsigned(2 downto 0);
	signal ROM_NEED_WAIT 	: std_logic;
	signal RAM_NEED_WAIT 	: std_logic;
	signal CODE_IN_ROM 		: std_logic;
	signal CODE_IN_RAM 		: std_logic;
	signal RAM_BYTES			: std_logic;	
	signal RAM_WORD			: std_logic;	
	signal RAM_LOAD_DATA		: std_logic_vector(15 downto 0);

	--CPU Code Cache
	signal CACHE_VALID		: std_logic_vector(31 downto 0);
	signal CACHE_POS			: unsigned(15 downto 0);
	signal CACHE_DST_ADDR	: unsigned(8 downto 0);
	signal CACHE_SRC_ADDR	: std_logic_vector(23 downto 0);
	signal CACHE_RUN			: std_logic;
	signal IN_CACHE			: std_logic;
	signal VAL_CACHE			: std_logic;
	signal BRAM_CACHE_ADDR_A: std_logic_vector(8 downto 0);
	signal BRAM_CACHE_ADDR_B: std_logic_vector(8 downto 0);
	signal BRAM_CACHE_DI_A	: std_logic_vector(7 downto 0);
	signal BRAM_CACHE_DI_B	: std_logic_vector(7 downto 0);
	signal BRAM_CACHE_Q_A	: std_logic_vector(7 downto 0);
	signal BRAM_CACHE_Q_B	: std_logic_vector(7 downto 0);
	signal BRAM_CACHE_WE_A	: std_logic;
	signal BRAM_CACHE_WE_B	: std_logic;
	
	--CPU Pixel Cache
	signal PIX_CACHE 			: PixCaches_t;
	signal PCF_RAM_A 			: std_logic_vector(16 downto 0);
	signal RPIX_RAM_A 		: std_logic_vector(16 downto 0);
	signal PCF_RD_DATA 		: std_logic_vector(7 downto 0);
	signal PCF_WR_DATA 		: std_logic_vector(7 downto 0);
	signal RPIX_DATA 			: std_logic_vector(7 downto 0);
	signal PCF_RW 				: std_logic;
	signal PCN 					: std_logic;
	signal PC0_FULL 			: std_logic;
	signal PC1_FULL 			: std_logic;
	signal PC0 					: integer range 0 to 1;
	signal PC1 					: integer range 0 to 1;
	signal PC_X 				: unsigned(7 downto 0);
	signal PC_Y 				: unsigned(7 downto 0);
	signal PC0_OFFS_HIT 		: std_logic;
	signal BPP_CNT 			: unsigned(2 downto 0);
	signal PLOT_EXEC 			: std_logic;
	
	--MMIO
	signal MMIO_SEL			: std_logic;
	signal MMIO_CACHE_SEL	: std_logic;
	signal MMIO_REG_SEL		: std_logic;
	signal ROM_SEL 			: std_logic;
	signal SRAM_SEL 			: std_logic;
	signal MMIO_WR 			: std_logic;
	signal MMIO_RD 			: std_logic;
	signal MMIO_CACHE_WR 	: std_logic;
	signal MMIO_REG_WR 		: std_logic;
	signal GSU_MEM_ACCESS 	: std_logic;
	signal GSU_ROM_ACCESS 	: std_logic;
	signal GSU_RAM_ACCESS 	: std_logic;
	signal SFR 					: std_logic_vector(15 downto 0);
	signal SNES_RAM_A 		: std_logic_vector(16 downto 0);
	signal INT_ROM_A 			: std_logic_vector(23 downto 0);
	signal SNES_CACHE_ADDR 	: std_logic_vector(8 downto 0);
	signal ROM_RD_CNT 		: unsigned(1 downto 0);

begin

	--IO Ports
	process(ADDR)
	begin
		MMIO_CACHE_SEL <= '0';
		MMIO_SEL <= '0';
		MMIO_REG_SEL <= '0';
		ROM_SEL <= '0';
		SRAM_SEL <= '0';
		SNES_RAM_A <= ADDR(16 downto 0);
		if ADDR(22) = '0' then
			if ADDR(15 downto 12) = x"3" then
				if ADDR(11 downto 8) = x"0" then
					if ADDR(7 downto 5) = "000" then												--00-3F:3000-301F, 80-BF:3000-301F
						MMIO_REG_SEL <= '1';
					else
						MMIO_SEL <= '1';																--00-3F:3030-30FF, 80-BF:3030-30FF
					end if;
				elsif ADDR(11 downto 8) = x"1" or ADDR(11 downto 8) = x"2"  then		--00-3F:3100-32FF, 80-BF:3100-32FF
					MMIO_CACHE_SEL <= '1';
				end if;
			elsif ADDR(15 downto 13) = "011"  then												--00-3F:6000-7FFF, 80-BF:6000-7FFF
				SRAM_SEL <= '1';
				SNES_RAM_A <= "0000" & ADDR(12 downto 0);
			elsif ADDR(15) = '1' then 	
				ROM_SEL <= '1';
			end if;
		else
			if ADDR(21) = '0' then																	--40-5F:0000-FFFF, C0-DF:0000-FFFF
				ROM_SEL <= '1';
			elsif ADDR(23 downto 17) = x"7" & "000" then										--70-71:0000-FFFF
				SRAM_SEL <= '1';
			end if;
		end if;
	end process;
	
	MMIO_CACHE_WR <= MMIO_CACHE_SEL and SYSCLKF_CE and not WR_N;
	MMIO_WR <= MMIO_SEL and SYSCLKF_CE and not WR_N;
	MMIO_RD <= MMIO_SEL and SYSCLKF_CE and not RD_N;
	MMIO_REG_WR <= MMIO_REG_SEL and SYSCLKF_CE and not WR_N;
	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			BRAMR <= (others => '0');
			PBR <= (others => '0');
			FLAG_GO <= '0';
			FLAG_IRQ <= '0';
			MS0 <= '0';
			IRQ_OFF <= '0';
			SCBR <= (others => '0');
			CLS <= '0';
			SCMR_MD <= (others => '0');
			SCMR_HT <= (others => '0');
			RAN <= '0';
			RON <= '0';
			GSU_MEM_ACCESS <= '0';
		elsif rising_edge(CLK) then
			if ENABLE = '1' then
				if MMIO_WR = '1' then
					if ADDR(7 downto 0) = x"30" then	--SFR LSB
						FLAG_GO <= DI(5);
						GSU_MEM_ACCESS <= DI(5);
					elsif ADDR(7 downto 0) = x"3A" then	--SCMR
						SCMR_MD <= DI(1 downto 0);
						SCMR_HT <= DI(5) & DI(2);
						RAN <= DI(3);
						RON <= DI(4);
					end if;
				elsif MMIO_RD = '1' and ADDR(7 downto 0) = x"31" then	--SFR MSB
					FLAG_IRQ <= '0';
				end if;
				
				if EN = '0' then
					if MMIO_REG_WR = '1' and ADDR(4 downto 0) = "11111" then
						FLAG_GO <= '1';
						GSU_MEM_ACCESS <= '1';
					elsif MMIO_WR = '1' and ADDR(7 downto 4) = x"3" then
						case ADDR(3 downto 0) is
							when x"3" =>						-- 3033
								BRAMR <= DI;
							when x"4" =>						-- 3034
								PBR <= DI;
							when x"7" =>						-- 3037
								MS0 <= DI(5);
								IRQ_OFF <= DI(7);
							when x"8" =>						-- 3038
								SCBR <= DI;
							when x"9" =>						-- 3039
								CLS <= DI(0);
							when others => null;
						end case;
					end if;
				elsif CPU_EN = '1' then 
					if OP.OP = OP_STOP then
						FLAG_GO <= '0';
						FLAG_IRQ <= '1';
						if SYSCLKF_CE = '1' then
							GSU_MEM_ACCESS <= '0';
						end if;
					elsif OP.OP = OP_LJMP then
						PBR <= R(to_integer(OP_N))(7 downto 0);
					end if;
				end if;
				
				if SYSCLKF_CE = '1' and FLAG_GO = '0' and GSU_MEM_ACCESS = '1' then
					GSU_MEM_ACCESS <= '0';
				end if;
			end if;
		end if;
	end process; 
	
	GSU_ROM_ACCESS <= GSU_MEM_ACCESS and RON;
	GSU_RAM_ACCESS <= GSU_MEM_ACCESS and RAN;
	
	
	SFR <= FLAG_IRQ & "0" & "0" & FLAG_B & "0" & "0" & FLAG_ALT2 & FLAG_ALT1 & "0" & FLAG_R & FLAG_GO & FLAG_OV & FLAG_S & FLAG_CY & FLAG_Z & "0";
	
	process( MMIO_SEL, MMIO_REG_SEL, MMIO_CACHE_SEL, ROM_SEL, SRAM_SEL, ADDR, 
				R, SFR, BRAMR, PBR, ROMBR, RAMBR, CBR, BRAM_CACHE_Q_B, FLAG_GO, GSU_ROM_ACCESS, ROM_DI, RAM_DI )
	begin
		DO <= x"00";
		if ROM_SEL = '1' then
			if GSU_ROM_ACCESS = '0' then
				DO <= ROM_DI;
			else	
				if ADDR(0) = '1' then
					DO <= x"01";
				elsif ADDR(3 downto 0) = x"E" then
					DO <= x"0C";
				elsif ADDR(3 downto 0) = x"A" then
					DO <= x"08";
				elsif ADDR(3 downto 0) = x"4" then
					DO <= x"04";
				else
					DO <= x"00";
				end if;
			end if;
		elsif MMIO_REG_SEL = '1' then
			if ADDR(0) = '0' then
				DO <= R(to_integer(unsigned(ADDR(4 downto 1))))(7 downto 0);
			else
				DO <= R(to_integer(unsigned(ADDR(4 downto 1))))(15 downto 8);
			end if;
		elsif MMIO_SEL = '1' then
			case ADDR(7 downto 0) is
				when x"30" =>						-- 3030 SFR
					DO <= SFR(7 downto 0);
				when x"31" =>						-- 3031 SFR
					DO <= SFR(15 downto 8);
				when x"33" =>						-- 3033 BRAMR
					DO <= BRAMR;
				when x"34" =>						-- 3034 PBR
					DO <= PBR;
				when x"36" =>						-- 3036 ROMBR
					DO <= ROMBR;
				when x"3B" =>						-- 303B VCR
					DO <= x"04";
				when x"3C" =>						-- 303C RAMBR
					DO <= RAMBR;
				when x"3E" =>						-- 303E CBR
					DO <= CBR(7 downto 0);
				when x"3F" =>						-- 303F CBR
					DO <= CBR(15 downto 8);
				when others => null;
			end case;
		elsif MMIO_CACHE_SEL = '1' then
			DO <= BRAM_CACHE_Q_B;
		elsif SRAM_SEL = '1' then
			DO <= RAM_DI;
		end if;
	end process;

	INT_ROM_A <= ADDR when GSU_ROM_ACCESS = '0' else 
					 CACHE_SRC_ADDR when ROMST = ROMST_CACHE and GSU_ROM_ACCESS = '1' else 
					 ROMBR & R(14) when ROMST = ROMST_LOAD and GSU_ROM_ACCESS = '1' else 
					 PBR & R(15) when ROMST = ROMST_FETCH and GSU_ROM_ACCESS = '1' else 
					 (others => '1');

				
	ROM_A <= INT_ROM_A(20 downto 0) when INT_ROM_A(22) = '1' else INT_ROM_A(21 downto 16) & INT_ROM_A(14 downto 0);
	
	RAM_A <= SNES_RAM_A when GSU_RAM_ACCESS = '0' else 
				CACHE_SRC_ADDR(16 downto 0) when RAMST = RAMST_CACHE and GSU_RAM_ACCESS = '1' else 
				RAMBR(0) & RAMADDR(15 downto 1) & (RAMADDR(0) xor RAM_BYTES) when (RAMST = RAMST_LOAD or RAMST = RAMST_SAVE) and GSU_RAM_ACCESS = '1' else
				PBR(0) & R(15) when RAMST = RAMST_FETCH and GSU_RAM_ACCESS = '1' else 
				PCF_RAM_A when RAMST = RAMST_PCF and GSU_RAM_ACCESS = '1' else
				RPIX_RAM_A when RAMST = RAMST_RPIX and GSU_RAM_ACCESS = '1' else
				SNES_RAM_A;
				
	RAM_DO <= DI when GSU_RAM_ACCESS = '0' else 
				 RAMDR( 7 downto 0) when RAMST = RAMST_SAVE and RAM_BYTES = '0' and GSU_RAM_ACCESS = '1' else
				 RAMDR(15 downto 8) when RAMST = RAMST_SAVE and RAM_BYTES = '1' and GSU_RAM_ACCESS = '1' else
				 PCF_WR_DATA when RAMST = RAMST_PCF and GSU_RAM_ACCESS = '1' else
				 DI;
	
	RAM_WE_N <= '1' when ENABLE = '0' else 
					WR_N when GSU_RAM_ACCESS = '0' else 
					'0' when RAMST = RAMST_SAVE and RAM_ACCESS_CNT = 0 and GSU_RAM_ACCESS = '1' and EN = '1' else 
					not PCF_RW when RAMST = RAMST_PCF and RAM_ACCESS_CNT = 0 and GSU_RAM_ACCESS = '1' else 
					'1';

	RAM_CE_N <= '0' when ENABLE = '0' else 
					not SRAM_SEL when GSU_RAM_ACCESS = '0' else 
					'0' when RAMST /= RAMST_IDLE and GSU_RAM_ACCESS = '1' else 
					'1';

	IRQ_N <= not FLAG_IRQ or IRQ_OFF;
	
	
	--CPU Core
	CODE_IN_ROM <= '1' when PBR <= x"5F" else '0';
	CODE_IN_RAM <= '1' when PBR(7 downto 1) = "0111000" else '0';
	IN_CACHE <= '1' when CACHE_POS(15 downto 9) = "0000000" else '0';
	VAL_CACHE <= CACHE_VALID(to_integer(CACHE_POS(8 downto 4)));
	
	CACHE_FETCH_EN <= VAL_CACHE and IN_CACHE;
	ROM_FETCH_EN <= '1' when ROMST = ROMST_FETCH and ROM_ACCESS_CNT = 0 and RON = '1' else '0';
	RAM_FETCH_EN  <= '1' when RAMST = RAMST_FETCH and RAM_ACCESS_CNT = 0 and RAN = '1' else '0';
	ROM_CACHE_EN <= '1' when ROMST = ROMST_CACHE and ROM_ACCESS_CNT = 0 and RON = '1' else '0';
	RAM_CACHE_EN  <= '1' when RAMST = RAMST_CACHE and RAM_ACCESS_CNT = 0 and RAN = '1' else '0';
	ROM_LOAD_EN <= '1' when ROMST = ROMST_LOAD and ROM_ACCESS_CNT = 0 and RON = '1' else '0';
	RAM_LOAD_EN  <= '1' when RAMST = RAMST_LOAD and RAM_ACCESS_CNT = 0 and RAM_BYTES = RAM_WORD and RAN = '1' else '0';
	
	ROM_NEED_WAIT <= '1' when (R14_CHANGE = '1' or MC.ROMWAIT = '1') and (ROMST = ROMST_LOAD or ROMST = ROMST_CACHE or (ROMST = ROMST_FETCH and ROM_ACCESS_CNT /= 0) or RON = '0') else '0';
	RAM_NEED_WAIT <= '1' when (OP.OP = OP_STOP and (RAMST = RAMST_SAVE or RAMST = RAMST_PCF)) or 
	                          (MC.RAMWAIT = '1' and (RAMST = RAMST_SAVE or RAMST = RAMST_PCF or RAN = '0')) or
									  RAMST = RAMST_LOAD or RAMST = RAMST_CACHE or (RAMST = RAMST_FETCH and RAM_ACCESS_CNT /= 0) or RAMST = RAMST_RPIX else '0';
	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			CLK_CE <= '0';
		elsif rising_edge(CLK) then
			if ENABLE = '1' then
				CLK_CE <= not CLK_CE;
			end if;
		end if;
	end process; 
	
	SPEED <= CLS or TURBO;
	
	EN <= ENABLE and FLAG_GO and (CLK_CE or SPEED);
	
	OP_CYCLES <= "000" when TURBO = '1' else
					 not (MS0 and not SPEED) & "10" when OP.OP = OP_FMULT or OP.OP = OP_LMULT else
					 "00" & not (MS0 and not SPEED) when OP.OP = OP_MULT or OP.OP = OP_UMULT else
					 "000";
	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			OP_CYCLE_CNT <= (others => '0');
		elsif rising_edge(CLK) then
			if EN = '1' then
				OP_CYCLE_CNT <= OP_CYCLE_CNT + 1;
				if OP_CYCLE_CNT = OP_CYCLES then
					OP_CYCLE_CNT <= (others => '0');
				end if;
			end if;
		end if;
	end process; 
	
	OP_CYCLE_EN <= '1' when OP_CYCLE_CNT = OP_CYCLES else '0';
	CPU_EN <= EN and (ROM_FETCH_EN or RAM_FETCH_EN or (CACHE_FETCH_EN and OP_CYCLE_EN)) and not RAM_NEED_WAIT and not ROM_NEED_WAIT;
	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			OPCODE <= x"01";
			OPDATA <= (others => '0');
		elsif rising_edge(CLK) then
			if CPU_EN = '1' then
				if OP.OP = OP_STOP then
					OPCODE <= x"01";
				elsif IN_CACHE = '1' then
					if MC.LAST_CYCLE = '1' then
						OPCODE <= BRAM_CACHE_Q_A;
					else
						OPDATA <= BRAM_CACHE_Q_A;
					end if;
				elsif ROM_FETCH_EN = '1' then
					if MC.LAST_CYCLE = '1' then
						OPCODE <= ROM_DI;
					else
						OPDATA <= ROM_DI;
					end if;
				elsif RAM_FETCH_EN = '1' then
					if MC.LAST_CYCLE = '1' then
						OPCODE <= RAM_DI;
					else
						OPDATA <= RAM_DI;
					end if;
				end if;
			end if;
		end if;
	end process; 
	
	
	--CPU Code cache
	CACHE_POS <= unsigned(R(15)) - unsigned(CBR);
	SNES_CACHE_ADDR <= not ADDR(8) & ADDR(7 downto 0);
	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			CACHE_RUN <= '0';
			CACHE_VALID <= (others => '0');
			CACHE_DST_ADDR <= (others => '0');
			CACHE_SRC_ADDR <= (others => '0');
			CBR <= (others => '0');
		elsif rising_edge(CLK) then
			if ENABLE = '1' then
				if MMIO_WR = '1' and ADDR(7 downto 0) = x"30" then	--SFR
					if FLAG_GO = '1' and DI(5) = '0' then
						CBR <= (others => '0');
						CACHE_VALID <= (others => '0');
					end if;
				end if;

				if EN = '0' then
					if MMIO_WR = '1' and ADDR(7 downto 0) = x"34" then	--PBR
						CACHE_VALID <= (others => '0');
					elsif MMIO_CACHE_WR = '1' and ADDR(3 downto 0) = x"F" then
						CACHE_VALID(to_integer(unsigned(SNES_CACHE_ADDR(8 downto 4)))) <= '1';
					end if;
				else
					if IN_CACHE = '1' and VAL_CACHE = '0' and CACHE_RUN = '0' then
						CACHE_RUN <= '1';
						CACHE_DST_ADDR <= CACHE_POS(8 downto 4) & x"0";
						CACHE_SRC_ADDR <= std_logic_vector( (unsigned(PBR) & x"0000") + ((unsigned(CBR(15 downto 4)) + CACHE_POS(15 downto 4)) & x"0") );
					end if;
						
					if CPU_EN = '1' then
						if (OP.OP = OP_CACHE and CBR(15 downto 4) /= R(15)(15 downto 4)) then
							CBR <= R(15)(15 downto 4) & x"0";
							CACHE_VALID <= (others => '0');
						elsif OP.OP = OP_LJMP then
							CBR <= R(to_integer(SREG))(15 downto 4) & x"0";
							CACHE_VALID <= (others => '0');
						end if;
					elsif CACHE_RUN = '1' then
						if ROM_CACHE_EN = '1' or RAM_CACHE_EN = '1' then
							CACHE_SRC_ADDR <= std_logic_vector( unsigned(CACHE_SRC_ADDR) + 1 );
							CACHE_DST_ADDR <= CACHE_DST_ADDR + 1;
							if CACHE_DST_ADDR(3 downto 0) = 15 then
								CACHE_VALID(to_integer(CACHE_DST_ADDR(8 downto 4))) <= '1';
								CACHE_RUN <= '0';
							end if;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process; 
	
	CACHE : entity work.dpram_difclk generic map(9, 8, 9, 8)
	port map(
		clock0		=> not CLK,
		address_a	=> BRAM_CACHE_ADDR_A,
		data_a		=> BRAM_CACHE_DI_A,
		wren_a		=> BRAM_CACHE_WE_A,
		q_a			=> BRAM_CACHE_Q_A,
		
		clock1		=> CLK,
		address_b	=> BRAM_CACHE_ADDR_B,
		data_b		=> BRAM_CACHE_DI_B,
		wren_b		=> BRAM_CACHE_WE_B,
		q_b			=> BRAM_CACHE_Q_B
	);
	BRAM_CACHE_ADDR_A <= std_logic_vector(CACHE_DST_ADDR) when ROMST = ROMST_CACHE or RAMST = RAMST_CACHE else std_logic_vector(CACHE_POS(8 downto 0));
	BRAM_CACHE_DI_A <= ROM_DI when CODE_IN_ROM = '1' else 
					  RAM_DI when CODE_IN_RAM = '1' else
					  x"00";
	BRAM_CACHE_WE_A <= '1' when ROM_CACHE_EN = '1' or RAM_CACHE_EN = '1' else '0';
	
	BRAM_CACHE_ADDR_B <= SNES_CACHE_ADDR;
	BRAM_CACHE_DI_B <= DI;
	BRAM_CACHE_WE_B <= MMIO_CACHE_WR when ENABLE = '1' and FLAG_GO = '0' else '0';
	
	
	--Memory buses
	R14_CHANGE <= '1' when DST_REG = 14 and (MC.DREG(1) = '1' or MC.DREG(0) = '1') and MC.LAST_CYCLE = '1' else '0';
	
	process(CLK, RST_N)
	variable ROM_CYCLES : unsigned(2 downto 0);
	begin
		if RST_N = '0' then
			ROMDR <= (others => '0');
			ROM_ACCESS_CNT <= "010";
			ROMST <= ROMST_IDLE;
			FLAG_R <= '0';
		elsif rising_edge(CLK) then
			if EN = '1' then
				if TURBO = '1' then
					ROM_CYCLES := "011";
				elsif SPEED = '0' then
					ROM_CYCLES := "010";
				else 
					ROM_CYCLES := "100";
				end if;
				
				case ROMST is
					when ROMST_IDLE =>
					
					when ROMST_FETCH =>
						if IN_CACHE = '1' then
							ROMST <= ROMST_IDLE;
						end if;
					
					when ROMST_LOAD =>
						if ROM_ACCESS_CNT = 0 and RON = '1' then
							ROMDR <= ROM_DI;
							FLAG_R <= '0';
							ROMST <= ROMST_IDLE;
						end if;
					
					when ROMST_CACHE =>
						if ROM_ACCESS_CNT = 0 and RON = '1' then
							if CACHE_DST_ADDR(3 downto 0) = 15 then
								ROMST <= ROMST_IDLE;
							end if;
						end if;
						
					when others => null;	
				end case;
				
				if CPU_EN = '1' and (OP.OP = OP_STOP) then
					ROMST <= ROMST_IDLE;
				elsif (ROMST = ROMST_IDLE and RON = '1') or ROM_FETCH_EN = '1' or ROM_LOAD_EN = '1' then
					if CPU_EN = '1' and R14_CHANGE = '1' then
						FLAG_R <= '1';
						ROMST <= ROMST_LOAD;
					elsif IN_CACHE = '0' and CODE_IN_ROM = '1' and (ROMST = ROMST_IDLE or ROMST = ROMST_LOAD) then
						ROMST <= ROMST_FETCH;
					elsif IN_CACHE = '1' and VAL_CACHE = '0' and CODE_IN_ROM = '1' and ROMST = ROMST_IDLE then
						ROMST <= ROMST_CACHE;
					end if;
				end if;
				
				if ROMST /= ROMST_IDLE and RON = '1' then
					ROM_ACCESS_CNT <= ROM_ACCESS_CNT - 1;
					if ROM_ACCESS_CNT = 0 then
						ROM_ACCESS_CNT <= ROM_CYCLES;
					end if;
				else
					ROM_ACCESS_CNT <= ROM_CYCLES;
				end if;
			end if;
		end if;
	end process; 
	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			ROM_RD_N <= '1';
			ROM_RD_CNT <= (others => '0');
		elsif rising_edge(CLK) then
			ROM_RD_N <= '1';
			if GSU_ROM_ACCESS = '0' then
				if SYSCLKR_CE = '1' or SYSCLKF_CE = '1' then
					ROM_RD_N <= '0';
					ROM_RD_CNT <= (others => '0');
				end if;
			else
				ROM_RD_CNT <= ROM_RD_CNT + 1;
				if ROM_RD_CNT = 1 then
					ROM_RD_CNT <= (others => '0');
					ROM_RD_N <= '0';
				end if;
			end if;
		end if;
	end process;
	
	process(CLK, RST_N)
		variable RAM_CYCLES : unsigned(2 downto 0);
	begin
		if RST_N = '0' then
			RAMADDR <= (others => '0');
			RAMDR <= (others => '0');
			RAM_LOAD_DATA <= (others => '0');
			RAM_WORD <= '0';
			RAM_BYTES <= '0';
			RAM_ACCESS_CNT <= "001";
			RAMST <= RAMST_IDLE;
			PCF_RW <= '0';
		elsif rising_edge(CLK) then
			if EN = '1' then
				if TURBO = '1' then
					RAM_CYCLES := "011";
				elsif SPEED = '0' then
					RAM_CYCLES := "001";
				else 
					RAM_CYCLES := "100";
				end if;
				
				if CPU_EN = '1' then
					if MC.RAMADDR = "001" then
						RAMADDR(7 downto 0) <= OPDATA;
					elsif MC.RAMADDR = "010" then
						RAMADDR(15 downto 8) <= OPDATA;
					elsif MC.RAMADDR = "011" then
						RAMADDR <= R(to_integer(OP_N));
					elsif MC.RAMADDR = "100" then
						RAMADDR <= "0000000" & OPDATA & "0";
					end if;
				end if;
			
				case RAMST is
					when RAMST_IDLE =>
						
					when RAMST_FETCH =>
						if IN_CACHE = '1' then
							RAMST <= RAMST_IDLE;
						end if;
												
					when RAMST_CACHE =>
						if RAM_ACCESS_CNT = 0 and RAN = '1' then
							if CACHE_DST_ADDR(3 downto 0) = 15 then
								RAMST <= RAMST_IDLE;
							end if;
						end if;
						
					when RAMST_LOAD =>
						if RAM_ACCESS_CNT = 0 and RAN = '1' then
							RAM_BYTES <= '1';
							if RAM_BYTES = '0' then
								RAM_LOAD_DATA(7 downto 0) <= RAM_DI;
							else
								RAM_LOAD_DATA(15 downto 8) <= RAM_DI;
							end if;
							if RAM_BYTES = RAM_WORD then
								RAMST <= RAMST_IDLE;
							end if;
						end if;
						
					when RAMST_SAVE =>
						if RAM_ACCESS_CNT = 0 and RAN = '1' then
							RAM_BYTES <= '1';
							if RAM_BYTES = RAM_WORD then
								RAMST <= RAMST_IDLE;
							end if;
						end if;
						
					when RAMST_PCF =>
						if RAM_ACCESS_CNT = 0 and RAN = '1' then
							if PC1_FULL = '0' then
								PCF_RW <= not PCF_RW;
							end if;

							if BPP_CNT = GetLastBPP(SCMR_MD) and PCF_RW = '1' then
								PCF_RW <= '0';
								if OP.OP = OP_RPIX then
									RAMST <= RAMST_RPIX;
								else
									RAMST <= RAMST_IDLE;
								end if;
							end if;
						end if;
						
					when RAMST_RPIX =>
						if RAM_ACCESS_CNT = 0 and RAN = '1' then
							if BPP_CNT = GetLastBPP(SCMR_MD) then
								RAMST <= RAMST_IDLE;
							end if;
						end if;
					
					when others => null;	
				end case;
				
				if CPU_EN = '1' and OP.OP = OP_STOP then
					RAMST <= RAMST_IDLE;
				elsif (RAMST = RAMST_IDLE and RAN = '1') or RAM_FETCH_EN = '1' or RAM_LOAD_EN = '1' then
					if CPU_EN = '1' and MC.RAMADDR /= "000" then
						if MC.RAMLD /= "00" then
							RAM_WORD <= MC.RAMLD(1);
							RAM_BYTES <= '0';
							RAM_LOAD_DATA <= (others => '0');
							RAMST <= RAMST_LOAD;
						elsif MC.RAMST(1 downto 0) /= "00" then
							if MC.RAMST(2) = '0' then
								RAMDR <= R(to_integer(SREG));
							else
								RAMDR <= R(to_integer(OP_N));
							end if;
							RAM_WORD <= MC.RAMST(1);
							RAM_BYTES <= '0';
							RAMST <= RAMST_SAVE;
						end if;
					elsif IN_CACHE = '0' and CODE_IN_RAM = '1' and RAMST = RAMST_IDLE then
						RAMST <= RAMST_FETCH;
					elsif IN_CACHE = '1' and VAL_CACHE = '0' and CODE_IN_RAM = '1' and RAMST = RAMST_IDLE then
						RAMST <= RAMST_CACHE;
					elsif CPU_EN = '1' and OP.OP = OP_PLOT and PLOT_EXEC = '1' and (PC0_OFFS_HIT = '0' or PC0_FULL = '1') then
						PCF_RW <= PC0_FULL;
						RAMST <= RAMST_PCF;
					elsif CPU_EN = '1' and OP.OP = OP_RPIX and STATE = 0 then
						if PIX_CACHE(PC0).VALID /= x"00" then
							PCF_RW <= PC0_FULL;
							RAMST <= RAMST_PCF;
						else
							RAMST <= RAMST_RPIX;
						end if;
					end if;

				end if;

				if RAMST /= RAMST_IDLE and RAN = '1' then
					RAM_ACCESS_CNT <= RAM_ACCESS_CNT - 1;
					if RAM_ACCESS_CNT = 0 then
						RAM_ACCESS_CNT <= RAM_CYCLES;
					end if;
				else
					RAM_ACCESS_CNT <= RAM_CYCLES;
				end if;
			end if;
		end if;
	end process; 

	--CPU Opcode logic
	OPS <= OP_TBL(to_integer(unsigned(OPCODE)));
	OP <= (OP_MOVES, 5) when FLAG_B = '1' and OPS.OP.OP = OP_FROM else
			(OP_MOVE,  4) when FLAG_B = '1' and OPS.OP.OP = OP_TO else
			OPS.OP_ALT3   when FLAG_ALT1 = '1' and FLAG_ALT2 = '1' else
			OPS.OP_ALT2   when FLAG_ALT1 = '0' and FLAG_ALT2 = '1' else
			OPS.OP_ALT1   when FLAG_ALT1 = '1' and FLAG_ALT2 = '0' else
			OPS.OP;
			
	MC <= MC_TBL(OP.MC, STATE);
		
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			STATE <= 0;
		elsif rising_edge(CLK) then
			if CPU_EN = '1' then
				if MC.LAST_CYCLE = '0' then
					STATE <= STATE + 1;
				else
					STATE <= 0;
				end if;
			end if;
		end if;
	end process; 
	
	OP_N <= unsigned(OPCODE(3 downto 0));
	DST_REG <= DREG when MC.DREG(2) = '0' else OP_N;
	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			FLAG_B <= '0';
			FLAG_ALT1 <= '0';
			FLAG_ALT2 <= '0';
			DREG <= (others => '0');
			SREG <= (others => '0');
		elsif rising_edge(CLK) then
			if CPU_EN = '1' then
				if OP.OP = OP_TO then
					DREG <= OP_N;
				elsif OP.OP = OP_FROM then
					SREG <= OP_N;
				elsif OP.OP = OP_WITH then
					FLAG_B <= '1';
					DREG <= OP_N;
					SREG <= OP_N;
				elsif OP.OP = OP_ALT1 then
					FLAG_ALT1 <= '1';
				elsif OP.OP = OP_ALT2 then
					FLAG_ALT2 <= '1';
				elsif OP.OP = OP_ALT3 then
					FLAG_ALT1 <= '1';
					FLAG_ALT2 <= '1';
				elsif OP.OP /= OP_BRA and MC.LAST_CYCLE = '1' then
					FLAG_B <= '0';
					FLAG_ALT1 <= '0';
					FLAG_ALT2 <= '0';
					DREG <= (others => '0');
					SREG <= (others => '0');
				end if;
			end if;
		end if;
	end process; 
	
	
	--ALU
	process(OP, R, SREG, OP_N, FLAG_ALT1, FLAG_ALT2, FLAG_CY, FLAG_OV, ALUR, RPIX_DATA)
		variable A, B : unsigned(15 downto 0);
		variable TEMP : unsigned(16 downto 0);
		variable MUL_TEMP : signed(31 downto 0);
	begin
		A := unsigned(R(to_integer(SREG)));
		if FLAG_ALT2 = '1' and (OP.OP = OP_ADD or OP.OP = OP_SUB or OP.OP = OP_AND or OP.OP = OP_MULT or OP.OP = OP_UMULT or OP.OP = OP_OR or OP.OP = OP_XOR) then
			B := x"000" & OP_N;
		else
			B := unsigned(R(to_integer(OP_N)));
		end if;
		
		ALUR <= (others => '0');
		MULR <= (others => '0');
		ALUOV <= FLAG_OV;
		ALUCY <= FLAG_CY;
		if OP.OP = OP_SWAP then
			ALUR <= std_logic_vector(A(7 downto 0) & A(15 downto 8));
		elsif OP.OP = OP_NOT then
			ALUR <= std_logic_vector(not A);
		elsif OP.OP = OP_ADD then
			TEMP := ("0" & A) + ("0" & B) + ((0 to 15 => '0') & (FLAG_ALT1 and FLAG_CY));
			ALUR <= std_logic_vector(TEMP(15 downto 0));
			ALUOV <= (A(15) xor TEMP(15)) and (B(15) xor TEMP(15));
			ALUCY <= TEMP(16);
		elsif OP.OP = OP_SUB then
			TEMP := ("0" & A) - ("0" & B) - ((0 to 15 => '0') & (FLAG_ALT1 and not FLAG_CY));
			ALUR <= std_logic_vector(TEMP(15 downto 0));
			ALUOV <= (A(15) xor B(15)) and (A(15) xor TEMP(15));
			ALUCY <= not TEMP(16);
		elsif OP.OP = OP_CMP then
			TEMP := ("0" & A) - ("0" & B);
			ALUR <= std_logic_vector(TEMP(15 downto 0));
			ALUOV <= (A(15) xor B(15)) and (A(15) xor TEMP(15));
			ALUCY <= not TEMP(16);
		elsif OP.OP = OP_LSR then
			ALUR <= std_logic_vector("0" & A(15 downto 1));
			ALUCY <= A(0);
		elsif OP.OP = OP_ASR or OP.OP = OP_DIV2 then
			if OP.OP = OP_DIV2 and A = x"FFFF" then
				ALUR <= (others => '0');
			else
				ALUR <= std_logic_vector(A(15) & A(15 downto 1));
			end if;
			ALUCY <= A(0);
		elsif OP.OP = OP_ROL then
			ALUR <= std_logic_vector(A(14 downto 0) & FLAG_CY);
			ALUCY <= A(15);
		elsif OP.OP = OP_ROR then
			ALUR <= std_logic_vector(FLAG_CY & A(15 downto 1));
			ALUCY <= A(0);
		elsif OP.OP = OP_AND then
			ALUR <= std_logic_vector(A and (B xor (0 to 15 => FLAG_ALT1)));
		elsif OP.OP = OP_OR then
			ALUR <= std_logic_vector(A or B);
		elsif OP.OP = OP_XOR then
			ALUR <= std_logic_vector(A xor B);
		elsif OP.OP = OP_INC then
			ALUR <= std_logic_vector(B + 1);
		elsif OP.OP = OP_DEC or OP.OP = OP_LOOP then
			ALUR <= std_logic_vector(B - 1);
		elsif OP.OP = OP_MULT then
			ALUR <= std_logic_vector(signed(A(7 downto 0)) * signed(B(7 downto 0)));
		elsif OP.OP = OP_UMULT then
			ALUR <= std_logic_vector(A(7 downto 0) * B(7 downto 0));
		elsif OP.OP = OP_FMULT or OP.OP = OP_LMULT then
			MUL_TEMP := signed(A) * signed(R(6));
			ALUR <= std_logic_vector(MUL_TEMP(31 downto 16));
			MULR <= std_logic_vector(MUL_TEMP(15 downto 0));
			ALUCY <= MUL_TEMP(15);
		elsif OP.OP = OP_SEX then
			ALUR <= std_logic_vector((0 to 7 => A(7)) & A(7 downto 0));
		elsif OP.OP = OP_MERGE then
			ALUR <= R(7)(15 downto 8) & R(8)(15 downto 8);
			ALUCY <= R(7)(15) or R(7)(14) or R(7)(13) or R(8)(15) or R(8)(14) or R(8)(13);
			ALUOV <= R(7)(15) or R(7)(14) or R(8)(15) or R(8)(14);
		elsif OP.OP = OP_LOB then
			ALUR <= std_logic_vector(x"00" & A(7 downto 0));
		elsif OP.OP = OP_HIB then
			ALUR <= std_logic_vector(x"00" & A(15 downto 8));
		elsif OP.OP = OP_MOVES then
			ALUR <= std_logic_vector(B);
			ALUOV <= B(7);
		elsif OP.OP = OP_RPIX then
			ALUR <= x"00" & RPIX_DATA;
		end if;
		
		if OP.OP = OP_MERGE then
			ALUZ <= R(7)(15) or R(7)(14) or R(7)(13) or R(7)(12) or R(8)(15) or R(8)(14) or R(8)(13) or R(8)(12);
		elsif ALUR = x"0000" then
			ALUZ <= '1';
		else
			ALUZ <= '0';
		end if;
		
		if OP.OP = OP_MERGE then
			ALUS <= R(7)(15) or R(8)(15);
		elsif OP.OP = OP_LOB or OP.OP = OP_HIB then
			ALUS <= ALUR(7);
		else
			ALUS <= ALUR(15);
		end if;
	end process; 
	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			FLAG_Z <= '0';
			FLAG_S <= '0';
			FLAG_CY <= '0';
			FLAG_OV <= '0';
		elsif rising_edge(CLK) then
			if CPU_EN = '1' and MC.FSET = '1' then
				FLAG_Z <= ALUZ;
				FLAG_S <= ALUS;
				FLAG_CY <= ALUCY;
				FLAG_OV <= ALUOV;
			elsif MMIO_WR = '1' and ADDR(7 downto 0) = x"30" then	--SFR LSB
				FLAG_Z <= DI(1);
				FLAG_S <= DI(3);
				FLAG_CY <= DI(2);
				FLAG_OV <= DI(4);
			end if;
		end if;
	end process; 
	
	
	--Resisters
	process(CLK, RST_N)
		variable COND : std_logic;
	begin
		if RST_N = '0' then
			R <= (others => (others => '0'));
			RAMBR <= (others => '0');
			ROMBR <= (others => '0');
			REG_LSB <= (others => '0');
		elsif rising_edge(CLK) then
			if EN = '0' then 
				if MMIO_REG_WR = '1' then
					if ADDR(0) = '0' then
						REG_LSB <= DI;
					else
						R(to_integer(unsigned(ADDR(4 downto 1)))) <= DI & REG_LSB;
					end if;
				end if;
			elsif CPU_EN = '1' then
				if MC.INCPC = '1' then
					R(15) <= std_logic_vector(unsigned(R(15)) + 1);
				end if;
				
				if OP.OP = OP_LMULT then
					R(4) <= MULR;
				end if;
				
				if OP.OP = OP_BRA then
					case OP_N is
						when x"5" => COND := '1';								--BRA
						when x"6" => COND := not (FLAG_S xor FLAG_OV);	--BGE
						when x"7" => COND := FLAG_S xor FLAG_OV;			--BLT
						when x"8" => COND := not FLAG_Z;						--BNE
						when x"9" => COND := FLAG_Z;							--BEQ
						when x"A" => COND := not FLAG_S;						--BPL
						when x"B" => COND := FLAG_S;							--BMI
						when x"C" => COND := not FLAG_CY;					--BCC
						when x"D" => COND := FLAG_CY;							--BCS
						when x"E" => COND := not FLAG_OV;					--BVC
						when x"F" => COND := FLAG_OV;							--BVS
						when others =>  COND := '0';	
					end case;
					if STATE = 1 and COND = '1' then
						R(15) <= std_logic_vector(unsigned(R(15)) + ((0 to 7 => OPDATA(7)) & unsigned(OPDATA)));
					end if;
				elsif OP.OP = OP_JMP then
					R(15) <= R(to_integer(OP_N));
				elsif OP.OP = OP_LJMP then
					R(15) <= R(to_integer(SREG));
				elsif OP.OP = OP_LOOP then
					R(12) <= ALUR;
					if ALUZ = '0' then
						R(15) <= R(13);
					end if;
				elsif OP.OP = OP_LINK then
					R(11) <= std_logic_vector(unsigned(R(15)) + OP_N);
				elsif OP.OP = OP_PLOT then
					R(1) <= std_logic_vector(unsigned(R(1)) + 1);
				elsif OP.OP = OP_RAMB then
					RAMBR <= R(to_integer(SREG))(7 downto 0) and x"01";
				elsif OP.OP = OP_ROMB then
					ROMBR <= R(to_integer(SREG))(7 downto 0) and x"7F";
				elsif MC.DREG(1 downto 0) /= "00" then 
					if MC.FSET = '1' then
						R(to_integer(DST_REG)) <= ALUR;
					else
						case OP.OP is
							when OP_LDB | OP_LDW | OP_LM | OP_LMS => 
								if MC.RAMLD /= "00" then
									R(to_integer(DST_REG)) <= RAM_LOAD_DATA;
								end if;
							when OP_GETB  => 
								R(to_integer(DST_REG)) <= x"00" & ROMDR;
							when OP_GETBL => 
								R(to_integer(DST_REG)) <= R(to_integer(SREG))(15 downto 8) & ROMDR;
							when OP_GETBH => 
								R(to_integer(DST_REG)) <= ROMDR & R(to_integer(SREG))(7 downto 0);
							when OP_GETBS => 
								R(to_integer(DST_REG)) <= (0 to 7 => ROMDR(7)) & ROMDR;
							when OP_MOVE => 
								R(to_integer(DST_REG)) <= R(to_integer(SREG));
							when OP_IBT => 
								R(to_integer(DST_REG)) <= (0 to 7 => OPDATA(7)) & OPDATA;
							when OP_IWT => 
								if MC.DREG(0) = '1' then
									REG_LSB <= OPDATA;
								elsif MC.DREG(1) = '1' then
									R(to_integer(DST_REG)) <= OPDATA & REG_LSB;
								end if;
							when OP_INC | OP_DEC => 
								R(to_integer(DST_REG)) <= ALUR;
							when others => null;	
						end case;
					end if;
				end if;
			end if;
		end if;
	end process; 
	
	
	--Pixel cashe
	PC_X <= unsigned(R(1)(7 downto 0));
	PC_Y <= unsigned(R(2)(7 downto 0));
	
	PC0 <= 0 when PCN = '0' else 1;
	PC1 <= 0 when PCN = '1' else 1;
	PC0_FULL <= '1' when PIX_CACHE(PC0).VALID = x"FF" else '0';
	PC1_FULL <= '1' when PIX_CACHE(PC1).VALID = x"FF" else '0';
	PC0_OFFS_HIT <= '1' when PIX_CACHE(PC0).OFFSET = PC_Y & PC_X(7 downto 3) else '0';
	
	process(POR_TRANS, SCMR_MD, POR_FH, COLR )
	begin
		PLOT_EXEC <= '0';
		if POR_TRANS = '1' then
			PLOT_EXEC <= '1';
		elsif SCMR_MD /= "11" or POR_FH = '1' then
			if COLR(3 downto 0) /= "0000" then
				PLOT_EXEC <= '1';
			end if;
		else
			if COLR /= "00000000" then
				PLOT_EXEC <= '1';
			end if;
		end if;
	end process; 
			
	process(CLK, RST_N)
		variable NEW_COLOR : std_logic_vector(7 downto 0);
		variable COL_DITH : std_logic_vector(7 downto 0);
	begin
		if RST_N = '0' then
			POR_TRANS <= '0';
			POR_DITH <= '0';
			POR_HN <= '0';
			POR_FH <= '0';
			POR_OBJ <= '0';
			COLR <= (others => '0');
			PIX_CACHE <= (others => ((others =>(others => '0')),(others => '0'),(others => '0')));
			PCN <= '0';
			PCF_RD_DATA <= (others => '0');
			RPIX_DATA <= (others => '0');
			BPP_CNT <= (others => '0');
		elsif rising_edge(CLK) then
			if EN = '1' then
				if CPU_EN = '1' then
					if OP.OP = OP_CMODE then
						POR_TRANS <= R(to_integer(SREG))(0);
						POR_DITH <= R(to_integer(SREG))(1);
						POR_HN <= R(to_integer(SREG))(2);
						POR_FH <= R(to_integer(SREG))(3);
						POR_OBJ <= R(to_integer(SREG))(4);
					elsif OP.OP = OP_COLOR or OP.OP = OP_GETC then
						if OP.OP = OP_GETC then
							NEW_COLOR := ROMDR;
						else
							NEW_COLOR := R(to_integer(SREG))(7 downto 0);
						end if;
						if POR_HN = '1' then
							COLR(3 downto 0) <= NEW_COLOR(7 downto 4);
						else
							COLR(3 downto 0) <= NEW_COLOR(3 downto 0);
						end if;
						if POR_FH = '0' then
							COLR(7 downto 4) <= NEW_COLOR(7 downto 4);
						end if;
					elsif OP.OP = OP_PLOT then
						if POR_DITH = '1' and SCMR_MD /= "11" then
							if (R(1)(0) xor R(2)(0)) = '1' then
								COL_DITH := "0000" & COLR(7 downto 4);
							else
								COL_DITH := "0000" & COLR(3 downto 0);
							end if;
						else
							COL_DITH := COLR;
						end if;
						
						if PLOT_EXEC = '1' then
							if PC0_OFFS_HIT = '0' or PC0_FULL = '1' then
								PCN <= not PCN;
								PIX_CACHE(PC1).DATA(to_integer(not PC_X(2 downto 0))) <= COL_DITH;
								PIX_CACHE(PC1).OFFSET <= PC_Y & PC_X(7 downto 3);
								PIX_CACHE(PC1).VALID(to_integer(not PC_X(2 downto 0))) <= '1';
							else
								PIX_CACHE(PC0).DATA(to_integer(not PC_X(2 downto 0))) <= COL_DITH;
								PIX_CACHE(PC0).OFFSET <= PC_Y & PC_X(7 downto 3);
								PIX_CACHE(PC0).VALID(to_integer(not PC_X(2 downto 0))) <= '1';
							end if;
						end if;
					elsif OP.OP = OP_RPIX and STATE = 0 then
						PCN <= not PCN;
					end if;
				end if;
				
				if RAMST = RAMST_PCF and RAM_ACCESS_CNT = 0 and RAN = '1' then
					if PCF_RW = '0' then
						PCF_RD_DATA <= RAM_DI;
					else
						BPP_CNT <= BPP_CNT + 1;
						if BPP_CNT = GetLastBPP(SCMR_MD) then
							BPP_CNT <= (others => '0');
							PIX_CACHE(PC1).VALID <= (others => '0');
						end if;
					end if;
				elsif RAMST = RAMST_RPIX and RAM_ACCESS_CNT = 0 and RAN = '1' then
					RPIX_DATA(to_integer(BPP_CNT)) <= RAM_DI(to_integer(not PC_X(2 downto 0)));
					BPP_CNT <= BPP_CNT + 1;
					if BPP_CNT = GetLastBPP(SCMR_MD) then
						BPP_CNT <= (others => '0');
					end if;
				end if;
			end if;
		end if;
	end process; 
	
	PCF_WR_DATA <= (PCF_RD_DATA and not PIX_CACHE(PC1).VALID) or (GetPCData(PIX_CACHE(PC1),BPP_CNT) and PIX_CACHE(PC1).VALID);
	
	PCF_RAM_A <= GetCharOffset(PIX_CACHE(PC1).OFFSET, (SCMR_HT or POR_OBJ&POR_OBJ), SCMR_MD, BPP_CNT, SCBR);
	
	RPIX_RAM_A <= GetCharOffset(PC_Y & PC_X(7 downto 3), (SCMR_HT or POR_OBJ&POR_OBJ), SCMR_MD, BPP_CNT, SCBR);
	
end rtl;
