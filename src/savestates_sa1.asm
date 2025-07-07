sa1_save_init:
	lda.w SA1_CCNT			;// Check if SA1 is in reset
	bit #$20
	beq +
	jmp Save_mapper_init_end
+
	ora #$40				;// Not in reset. Pause SA1
	sta.w SA1_CCNT

sa1_save_dma_wait:
	lda.w SA1_DCNT
	bit #$20				;// if DMA==CCDMA
	bne sa1_save_dma_end	;// skip wait

	lda #$08
-
 	bit SA1_DCNT			;// Wait until normal DMA
	bne -					;// is finished


sa1_save_dma_end:
	lda #$01				;// Writing 1 will allow SA1 to continue
	sta.w SA1_SSCMD			;// SA1 will write 0 when done
	
	ldx.w #sa1_nmi_save		;// Overwrite NMI vector
	stx.w SA1_CNVL

	
	lda #$10
	sta.w SA1_CIE			;// Enable NMI
	
	lda.w SA1_CCNT
	and #$BF
	ora #$10				;// Resume SA1 and start NMI
	sta.w SA1_CCNT
	
-
	lda.w SA1_SSCMD
	bne -
	
							;// SA1 finished init
	a16()
	lda SSBASE+SA1_CNVL		;// Restore NMI vector
	sta.w SA1_CNVL
	a8()
	
	lda SSBASE+SA1_CIE
	sta.w SA1_CIE			;// Restore NMI enable
	
	jmp Save_mapper_init_end

sa1_save_regs_snes:
	lda.b #SS_SA1REGS1
	sta SSDATA

	lda #$00				;// clear B register
	xba
	
	ldy #$0000
-
	lda.w SA1RegsSNES,y
	sta SSDATA				;// Store register number in save state
	
	cmp #$FF
	beq sa1_save_regs_sa1
	
	tax
	lda.w SA1_REGBASE,x		;// Load value from register
	
	sta SSDATA				;// Store register value in save state

	iny
	bra -

sa1_save_regs_sa1:
	lda.b #SS_SA1REGS2
	sta SSDATA

	lda #$00				;// clear B register
	xba
	
	lda #$09				;// Store $2300 as register $09
	sta SSDATA
	lda.w SA1_SFR
	sta SSDATA
	
	ldy #$0000
-
	lda.w SA1RegsSA1,y
	sta SSDATA				;// Store register number in save state
	
	cmp #$FF
	beq sa1_save_iram
	
	tax
	lda.w SA1_REGBASE,x		;// Load value from register
	
	sta SSDATA				;// Store register value in save state

	iny
	bra -

sa1_save_iram:
	lda.b #SS_SA1IRAM
	sta SSDATA
	
	lda #$30
	xba
	lda #$00
	tcd						;// Set Direct page to $3000

	ldx #$0000
-
	lda $00,x				;// Read $3000-$37FF
	sta SSDATA
	
	inx
	cpx #$0800
	bne -
	
	lda #$00
	xba
	lda #$00
	tcd

	jmp Save_mapper_end

sa1_load_init:
	lda.w SA1_CCNT			;// Check if SA1 is in reset
	bit #$20
	beq +
	
	ldx.w #sa1_reset		;// Overwrite Reset vector
	stx.w SA1_CRVL
	
	stz SA1_CCNT			;// SA1 out of reset
	bra sa1_load_start_nmi
	
+
	lda #$40
	sta.w SA1_CCNT			;// Not in reset. Pause SA1
	
sa1_load_start_nmi:	
	lda #$01
	sta.w SA1_SSCMD
	
	ldx.w #sa1_nmi_load		;// Overwrite NMI vector
	stx.w SA1_CNVL
	
	lda #$10
	sta.w SA1_CIE			;// Enable NMI
	sta.w SA1_CCNT			;// Resume SA1 and start NMI
	
-
	lda.w SA1_SSCMD
	bne -
							;// SA1 finished init
	jmp Load_mapper_init_end
	
sa1_load_regs_snes:
	lda #$00				;// clear B register
	xba
	
-
	lda SSDATA				;// Load register index
	tax	
	
	cmp #$FF
	beq sa1_load_regs_sa1
	
	lda SSDATA				;// Load value from state
	
	cpx #$0000				;// Check for SA1_CCNT
	bne +
	tay
	
	and #$8F				;// Avoid resetting SA1 here
	sta.w SA1_CCNT
	
	tya
	sta.l SSBASE+SA1_CCNT	;// Store SA1 Reset in shadow register
	bra -

+
	sta.w SA1_REGBASE,x
	bra -

sa1_load_regs_sa1:
	lda SSDATA

	ldx #$0000
	
-
	lda SSDATA				;// Load register index
	sta.w SA1_IRAMREG,x		;// Store in IRAM for SA1
	inx
	
	cmp #$FF
	beq sa1_load_regs_sa1_wait
	
	lda SSDATA				;// Load value from state
	sta.w SA1_IRAMREG,x		;// Store in IRAM for SA1
	inx
	
	bra -
	
sa1_load_regs_sa1_wait:
	lda #$01				;// Let SA1 write to the registers
	sta.w SA1_SSCMD
	
-
	lda.w SA1_SSCMD
	bne -
	
sa1_load_iram:
	lda SSDATA
	
	lda #$30
	xba
	lda #$00
	tcd						;// Set Direct page to $3000

	ldx #$0000
-
	lda SSDATA
	sta $00,x				;// Write $3000-$37FF

	inx
	cpx #$0800
	bne -

	lda #$00
	xba
	lda #$00
	tcd

	jmp Load_other
	
sa1_finish:
	lda.l SSBASE+SA1_CCNT
	and #$20
	tsb.w SA1_CCNT			;// Restore SA1 reset
	
	lda #$01				;// SA1 will RTI after this,
	sta.w SA1_SSCMD			;// if not in reset
	
	jmp Mapper_finish


sa1_nmi_save:				;// NMI code runs on SA1 CPU
	sei
	php

	a16i16()
	pha
	phx
	phy
	phb
	phd
	
	phk
	plb
	
	a8()
	
	lda #$10
	sta.w SA1_CIC			;// Acknowledge NMI
	
	ldy $3002
	phy						;// Store $3002, $3003 in Stack
	
	tsx
	stx $3002				;// Stack pointer to $3002, $3003
	
	stz SA1_SSCMD			;// Signal ready to SNES
-
	lda.w SA1_SSCMD			;// Wait until SNES finished
	beq -					
	
sa1_nmi_finish:
	ply
	sty $3002				;// Restore $3002, $3003

	a16i16()
	pld
	plb
	ply
	plx
	pla

	plp

	jmp Return

sa1_nmi_load:
	sei

	a8i16()

	phk
	plb
	
	
	lda #$F0
	sta.w SA1_CIC			;// Clear all IRQs
	
	stz SA1_DCNT			;// Reset DMA
	
	stz SA1_SSCMD			;// Signal ready to SNES
	
-
	lda.w SA1_SSCMD			;// Wait until SNES finished
	beq -
	
sa1_nmi_load_regs:
	lda #$00				;// clear B register
	xba
	
	ldx #$0000

-
	lda.w SA1_IRAMREG,x		;// Load register index
	tay
	inx

	cmp #$FF
	beq sa1_nmi_load_regs_end
	
	lda.w SA1_IRAMREG,x		;// Load value
	inx
	
	sta.w SA1_REGBASE,y
	bra -

sa1_nmi_load_regs_end:
	stz SA1_SSCMD			;// Signal ready to SNES
	
-
	lda.w SA1_SSCMD			;// Wait until SNES finished
	beq -
	
	ldx $3002				;// Load stack pointer from $3002, $3003
	txs
	
	jmp sa1_nmi_finish

sa1_reset:
	sei
	
	clc
	xce
	
	a8i16()
	
	ldx #$37FF
	txs

-
	wai
	bra -
	
SA1RegsSNES:
	db $00, $01, $03, $04, $05, $06, $07, $08
	db $20, $21, $22, $23, $24, $26, $28, $29
	db $31, $32, $33, $34, $35, $36, $37, $FF
	
SA1RegsSA1:
	db $0A, $0C, $0D, $0E, $0F
	db $10, $12, $13, $14, $15, $16, $17, $18, $19, $1A
	db $25, $27, $2A
	db $30, $38, $39, $3F
	db $40, $41, $42, $43, $44, $45, $46, $47
	db $48, $49, $4A, $4B, $4C, $4D, $4E, $4F
	db $50, $51, $52, $53
	db $58, $59, $5A, $5B
	db $6A, $6B, $6C, $6D, $6E, $6F
	db $70, $71, $72, $73, $74, $75, $76, $77
	db $FF