cx4_save_regs:
	lda.b #SS_CX4REGS
	sta SSDATA

	;// MMIO regs read from $7Fxx; emitted first so the load writes them while CPU_RUN=0, before the shadow pairs restore it (CA 0x17).
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
	;// DMA_SRC + DMA_LEN  $7F40-$7F44  (5 B)
	ldx #$0000
-
	lda.l $007F40,x
	sta SSDATA
	inx
	cpx #$0005
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

	;// HW-kept internal regs via the SS shadow window, (CA,value) pairs, FF-terminated.  Ranges: 00-19, 4A-6A, 9F-BB.
	ldx #$0000
-
	txa
	sta SSDATA
	lda.l SS_CX4_BASE,x
	sta SSDATA
	inx
	cpx #$001A
	bne -
	ldx #$004A
-
	txa
	sta SSDATA
	lda.l SS_CX4_BASE,x
	sta SSDATA
	inx
	cpx #$006B
	bne -
	;// DMA_DST/PAGE_SEL/PAGE_LOCK/IRQ_EN: read via MMIO for the save, restored in HW (their writes side-effect).
	;// Emitted as (CA,value) pairs so the load side restores them through the SS shadow window like the rest.
	lda #$6E
	sta SSDATA
	lda.l $007F45
	sta SSDATA
	lda #$6F
	sta SSDATA
	lda.l $007F46
	sta SSDATA
	lda #$70
	sta SSDATA
	lda.l $007F47
	sta SSDATA
	lda #$78
	sta SSDATA
	lda.l $007F48
	sta SSDATA
	lda #$79
	sta SSDATA
	lda.l $007F4C
	sta SSDATA
	lda #$7E
	sta SSDATA
	lda.l $007F51
	eor #$01				;// $7F51 reads NOT IRQ_EN; store the true value
	sta SSDATA
	ldx #$009F
-
	txa
	sta SSDATA
	lda.l SS_CX4_BASE,x
	sta SSDATA
	inx
	cpx #$00BC
	bne -
cx4_save_regs_end:
	lda #$FF				;// Store register end marker
	sta SSDATA

cx4_save_ram:
	lda.b #SS_CX4RAM
	sta SSDATA

	sta SS_EXT_ADDR

	SetupDMA((DMA_DIR_BA | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_CX4_DATA, 4096)

	lda #$01
	sta $420B

cx4_save_cache:
	lda.b #SS_CX4CACHE		;// program cache block marker
	sta SSDATA

	sta SS_EXT_ADDR			;// reset SS external address counter to 0

	SetupDMA((DMA_DIR_BA | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_CX4_CACHE_DATA, 1024)

	lda #$01
	sta $420B

	jmp Save_mapper_end

cx4_load_regs:
	;// MMIO regs written first (CPU_RUN still 0 from reset).
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
	;// DMA_SRC + DMA_LEN  -> $7F40-$7F44  (5 B)
	ldx #$0000
-
	lda SSDATA
	sta.l $007F40,x
	inx
	cpx #$0005
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

	;// HW-kept internal regs via the SS shadow window (restores CPU_RUN 0x17 etc.), (CA,value) pairs until the FF terminator.
	lda #$00				;// clear B register
	xba
-
	lda SSDATA				;// Load register index
	tax

	cmp #$FF
	beq cx4_load_ram

	lda SSDATA				;// Load register value from save state

	sta.l SS_CX4_BASE,x

	bra -

cx4_load_ram:
	lda SSDATA				;// consume SS_CX4RAM marker

	sta SS_EXT_ADDR

	SetupDMA((DMA_DIR_AB | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_CX4_DATA, 4096)

	lda #$01
	sta $420B

cx4_load_cache:
	lda SSDATA				;// consume SS_CX4CACHE marker

	sta SS_EXT_ADDR			;// reset SS external address counter to 0

	SetupDMA((DMA_DIR_AB | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_CX4_CACHE_DATA, 1024)

	lda #$01
	sta $420B

	jmp Load_other
