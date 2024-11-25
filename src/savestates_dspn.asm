dspn_save_regs:
	lda.b #SS_DSPNREGS
	sta SSDATA

	ldx #$0000
-
	txa
	sta SSDATA				;// Store register number in save state

	lda.l SS_DSPN_BASE,x	;// Load value from register

	sta SSDATA				;// Store register value in save state

	cpx #$002F
	beq dspn_save_regs_end
	inx
	bra -
dspn_save_regs_end:
	lda #$FF				;// Store register end marker
	sta SSDATA

dspn_save_ram:
	lda.b #SS_DSPNRAM
	sta SSDATA

	sta SS_EXT_ADDR

	SetupDMA((DMA_DIR_BA | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_DSPN_DATA, 4096)

	lda #$01
	sta $420B

	jmp Save_mapper_end

dspn_load_regs:
	lda #$00				;// clear B register
	xba

-
	lda SSDATA				;// Load register index
	tax

	cmp #$FF
	beq dspn_load_ram

	lda SSDATA				;// Load register value from save state

	sta.l SS_DSPN_BASE,x

	bra -

dspn_load_ram:
	lda SSDATA				;// load block #

	sta SS_EXT_ADDR

	SetupDMA((DMA_DIR_AB | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_DSPN_DATA, 4096)

	lda #$01
	sta $420B

	jmp Load_other