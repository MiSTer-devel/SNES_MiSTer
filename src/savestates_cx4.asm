cx4_save_regs:
	lda.b #SS_CX4REGS
	sta SSDATA

	;// HW-kept internal regs via the SS shadow window, (CA,value) pairs, FF-terminated.
	;// One contiguous range 00-39 (single-bit regs are packed, see the save mux in CX4.vhd).
	;// Emitted BEFORE the MMIO regs: the load side replays the stream in order, and the
	;// GPR MMIO writes ($7F80-7FAF) are gated on CPU_RUN = 0 in hardware.  The load hijacks
	;// the NMI at game runtime (no reset), so CPU_RUN may be 1 at that point; restoring the
	;// pairs first clears it via CA 0x03 (the save is idle-gated, so the saved run bits are 0).
	ldx #$0000
-
	txa
	sta SSDATA
	lda.l SS_CX4_BASE,x
	sta SSDATA
	inx
	cpx #$003A
	bne -
cx4_save_regs_end:
	lda #$FF				;// Store register end marker
	sta SSDATA

	;// MMIO regs read from $7Fxx; emitted after the shadow pairs (see ordering note above).
	;// GPR(0..15)  $7F80-$7FAF  (48 B)
	ldx #$0000
-
	lda.l $007F80,x
	sta SSDATA
	inx
	cpx #$0030
	bne -
	;// VEC_MEM(0..31)  $7F60-$7F7F  (32 B)
	ldx #$0000
-
	lda.l $007F60,x
	sta SSDATA
	inx
	cpx #$0020
	bne -
	;// DMA_SRC + DMA_LEN + DMA_DST 7:0/15:8  $7F40-$7F46  (7 B)
	;// DMA_DST low/mid restore through MMIO (no side effect); DMA_DST 23:16 ($7F47) starts a DMA so it stays in the shadow window (CA 08).
	ldx #$0000
-
	lda.l $007F40,x
	sta SSDATA
	inx
	cpx #$0007
	bne -
	;// ROM_BASE  $7F49-$7F4B  (3 B)   -- skip $7F45-48 (DMA_DST/PAGE_SEL = HW)
	ldx #$0000
-
	lda.l $007F49,x
	sta SSDATA
	inx
	cpx #$0003
	bne -
	;// ROM_PAGE  $7F4D-$7F4E  (2 B)   -- skip $7F4C (PAGE_LOCK = HW), $7F4F (CPU trigger)
	ldx #$0000
-
	lda.l $007F4D,x
	sta SSDATA
	inx
	cpx #$0002
	bne -
	;// WS1/WS2  $7F50  (1 B)
	lda.l $007F50
	sta SSDATA
	;// ROM_MODE  $7F52  (1 B)   -- skip $7F51 (IRQ_EN = HW; its write clears IRQ)
	lda.l $007F52
	sta SSDATA
	;// SUSPEND  $7F5E bit0  (1 B)
	lda.l $007F5E
	and #$01
	sta SSDATA

cx4_save_ram:
	lda.b #SS_CX4RAM
	sta SSDATA

	;// Data RAM (3 KB) read through the RAMIO window $00:6000-6BFF; no dedicated SS port needed.
	ldx #$0000
-
	lda.l $006000,x
	sta SSDATA
	inx
	cpx #$0C00
	bne -

cx4_save_cache:
	lda.b #SS_CX4CACHE		;// program cache block marker
	sta SSDATA

	sta SS_EXT_ADDR			;// reset SS external address counter to 0

	SetupDMA((DMA_DIR_BA | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_CX4_CACHE_DATA, 1024)

	lda #$01
	sta $420B

	jmp Save_mapper_end

cx4_load_regs:
	;// HW-kept internal regs via the SS shadow window, (CA,value) pairs until the FF terminator.
	;// Restored FIRST: CA 0x03 clears CPU_RUN (the save is idle-gated, so the saved value is 0),
	;// which un-gates the CPU_RUN-gated MMIO writes below (GPR $7F80-7FAF) and the Data RAM
	;// window.  The load hijacks the NMI at game runtime, so CPU_RUN may be 1 on entry.
	lda #$00				;// clear B register
	xba
-
	lda SSDATA				;// Load register index
	tax

	cmp #$FF
	beq cx4_load_mmio

	lda SSDATA				;// Load register value from save state

	sta.l SS_CX4_BASE,x

	bra -

cx4_load_mmio:
	;// MMIO regs written after the pairs (CPU_RUN now 0, see ordering note above).
	;// NEVER write $7F47/$7F48/$7F4C/$7F4F/$7F51/$7F53/$7F5E (all side-effecting).
	;// GPR(0..15)  -> $7F80-$7FAF  (48 B)
	ldx #$0000
-
	lda SSDATA
	sta.l $007F80,x
	inx
	cpx #$0030
	bne -
	;// VEC_MEM(0..31)  -> $7F60-$7F7F  (32 B)
	ldx #$0000
-
	lda SSDATA
	sta.l $007F60,x
	inx
	cpx #$0020
	bne -
	;// DMA_SRC + DMA_LEN + DMA_DST 7:0/15:8  -> $7F40-$7F46  (7 B)
	ldx #$0000
-
	lda SSDATA
	sta.l $007F40,x
	inx
	cpx #$0007
	bne -
	;// ROM_BASE  -> $7F49-$7F4B  (3 B)
	ldx #$0000
-
	lda SSDATA
	sta.l $007F49,x
	inx
	cpx #$0003
	bne -
	;// ROM_PAGE  -> $7F4D-$7F4E  (2 B)
	ldx #$0000
-
	lda SSDATA
	sta.l $007F4D,x
	inx
	cpx #$0002
	bne -
	;// WS  -> $7F50  (1 B)
	lda SSDATA
	sta.l $007F50
	;// ROM_MODE  -> $7F52  (1 B)
	lda SSDATA
	sta.l $007F52
	;// SUSPEND strobe: write $7F55 if bit0 set, else $7F5D (the addr is the strobe; value ignored)
	lda SSDATA
	and #$01
	beq cx4_susp_clr
	sta.l $007F55
	bra cx4_susp_done
cx4_susp_clr:
	sta.l $007F5D
cx4_susp_done:

cx4_load_ram:
	lda SSDATA				;// consume SS_CX4RAM marker

	;// Data RAM (3 KB) written back through the RAMIO window $00:6000-6BFF (open during a LOAD).
	ldx #$0000
-
	lda SSDATA
	sta.l $006000,x
	inx
	cpx #$0C00
	bne -

cx4_load_cache:
	lda SSDATA				;// consume SS_CX4CACHE marker

	sta SS_EXT_ADDR			;// reset SS external address counter to 0

	SetupDMA((DMA_DIR_AB | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_CX4_CACHE_DATA, 1024)

	lda #$01
	sta $420B

	jmp Load_other
