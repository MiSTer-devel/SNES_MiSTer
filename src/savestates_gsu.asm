gsu_save_regs1:				;// Save R0-R15
	lda.b #SS_GSUREGS1
	sta SSDATA

	ldx #$0000
-
	txa
	sta SSDATA				;// Store register number in save state

	lda.w GSU_REGBASE,x		;// Load value from register

	sta SSDATA				;// Store register value in save state

	cpx #$001F
	beq gsu_save_regs1_end
	inx
	bra -
gsu_save_regs1_end:
	lda #$FF				;// Store register end marker
	sta SSDATA

gsu_save_cache:				;// Save 512 byte cache
	lda.b #SS_GSUCACHE
	sta SSDATA

	lda #$31
	xba
	lda #$00
	tcd						;// Set Direct page to $3100

	ldx #$0000
-
	lda $00,x				;// Read $3100-$32FF
	sta SSDATA

	inx
	cpx #$0200
	bne -

gsu_save_regs2:				;// Save internal state regs
	lda.b #SS_GSUREGS2
	sta SSDATA

	ldx #$0000
-
	txa
	sta SSDATA				;// Store register number in save state

	lda.l SS_GSU_BASE,x		;// Load value from register

	sta SSDATA				;// Store register value in save state

	cpx #$004F
	beq gsu_save_regs2_end
	inx
	bra -
gsu_save_regs2_end:
	lda #$FF				;// Store register end marker
	sta SSDATA

	jmp Save_mapper_end

gsu_load_regs1:
	lda #$00				;// clear B register
	xba

-
	lda SSDATA				;// Load register index
	tax

	cmp #$FF
	beq gsu_load_cache

	lda SSDATA				;// Load register value from save state

	sta.w GSU_REGBASE,x

	bra -

gsu_load_cache:
	lda SSDATA				;// load block #

	lda #$31
	xba
	lda #$00
	tcd						;// Set Direct page to $3100

	ldx #$0000
-
	lda SSDATA
	sta $00,x				;// Write $3100-$32FF

	inx
	cpx #$0200
	bne -

	lda #$00
	xba
	lda #$00
	tcd

gsu_load_regs2:
	lda SSDATA				;// load block #

-
	lda SSDATA				;// Load register index
	tax

	cmp #$FF
	beq gsu_load_regs2_end

	lda SSDATA				;// Load register value from save state

	sta.l SS_GSU_BASE,x

	bra -

gsu_load_regs2_end:
	jmp Load_other
