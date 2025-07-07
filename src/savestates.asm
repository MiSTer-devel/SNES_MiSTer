architecture snes.cpu

output "savestates.bin", create

origin 0
base $8000


constant SSBASE        = $C00000
constant SS_PPU        = $C10000

constant SSDATA        = $C06000
constant SSADDR        = $C06001
constant SS_EXT_ADDR   = $C06002
constant SS_BSRAMSIZE  = $C06003
constant SS_ROMTYPE    = $C06004
constant SS_END        = $C0600E
constant SS_STATUS     = $C0600F

constant STATUS_SAVE   = $01
constant STATUS_BUSY   = $02

constant ROM_SA1       = $60
constant ROM_DSP_MASK  = $C0
constant ROM_GSU       = $70
constant ROM_DSP       = $80

constant SS_WMADDL     = $C02181
constant SS_WMADDM     = $C02182
constant SS_WMADDH     = $C02183

constant SS_TEMP1      = $C021F0
constant SS_TEMP2      = $C021F1
constant SS_TEMP3      = $C021F2

constant SS_WRDIVLAST  = SSBASE + $420F

constant SS_ARAM_DATA  = $2184
constant SS_DSP_REGSD  = $2185
constant SS_SMP_REGSD  = $2186
constant SS_BSRAM_DATA = $2187
constant SS_DSPN_DATA  = $2188

constant NOSHADOW      = $010000

constant PPU_BASE      = $2100
constant INIDISP       = $2100
constant OAMADDL       = $2102
constant OAMADDH       = $2103
constant VMAIN         = $2115
constant VMADDL        = $2116
constant VMADDH        = $2117
constant CGADD         = $2121
constant CGDATA        = $2122
constant COLDATA       = $2132
constant VMDATALREAD   = $2139
constant VMDATAHREAD   = $213A

constant PPU_HBASE     = $2140
constant COLDATA2      = $2140
constant COLDATA3      = $2141
constant CGADD0        = $2161

constant SA1_REGBASE   = $2200
constant SA1_CCNT      = $2200
constant SA1_SCNT      = $2209
constant SA1_CIE       = $220A
constant SA1_CIC       = $220B
constant SA1_CRVL      = $2203
constant SA1_CRVH      = $2204
constant SA1_CNVL      = $2205
constant SA1_CNVH      = $2206
constant SA1_SIWP      = $2229
constant SA1_DCNT      = $2230
constant SA1_SSCMD     = $22FF
constant SA1_SFR       = $2300
constant SA1_IRAMREG   = $3010

constant WMADDL        = $2181
constant WMADDM        = $2182
constant WMADDH        = $2183

constant NMITIMEN      = $4200
constant WRIO          = $4201
constant WRMPYA        = $4202
constant WRMPYB        = $4203
constant WRDIVL        = $4204
constant WRDIVH        = $4205
constant WRDIVB        = $4206
constant HTIMEL        = $4207
constant HTIMEH        = $4208
constant VTIMEL        = $4209
constant VTIMEH        = $420A
constant HDMAEN        = $420C
constant MEMSEL        = $420D
constant RDNMI         = $4210
constant HVBJOY        = $4212

constant SS_DSPN_BASE  = SSBASE + $6100
constant SS_GSU_BASE   = SSBASE + $6200

constant GSU_REGBASE   = $3000

constant DMA_DIR_AB = $00
constant DMA_DIR_BA = $80
constant DMA_FIXED_A = $08
constant DMA_MODE_0 = $00
constant DMA_MODE_1 = $01

constant SS_WRAM     = $00
constant SS_VRAM     = $01
constant SS_OAM      = $02
constant SS_CGRAM    = $03
constant SS_ARAM     = $04
constant SS_DPSREGS  = $05
constant SS_SMPREGS  = $06
constant SS_PPUPREGS1 = $07
constant SS_PPUPREGS2 = $08
constant SS_MMIOREGS  = $09
constant SS_BSRAM     = $0A
constant SS_DMAREGS   = $0B
constant SS_SA1REGS1  = $0C
constant SS_SA1REGS2  = $0D
constant SS_SA1IRAM   = $0E
constant SS_DSPNREGS  = $0F
constant SS_DSPNRAM   = $10
constant SS_GSUREGS1  = $11
constant SS_GSUCACHE  = $12
constant SS_GSUREGS2  = $13

macro a8() {
	sep #$20
}

macro a8i8() {
	sep #$30
}

macro a8i16() {
	sep #$20
	rep #$10
}

macro a16() {
	rep #$20
}

macro a16i16() {
	rep #$30
}

macro SetupDMA(DMAP, A, B, LEN) {
	lda.b #{DMAP}
	sta $4300
	
	lda.b #{B}
	sta $4301
	
	lda.b #{A}
	sta $4302
	
	lda.b #({A} >> 8)
	sta $4303
	
	lda.b #({A} >> 16)
	sta $4304
	
	lda.b #{LEN}
	sta $4305
	
	lda.b #({LEN} >> 8)
	sta $4306
}

									;// Fixed addresses
	jml Save_start					;// $8000 Save
	jml Load_start					;// $8004 Load
Return:								;// $8008 Return
	rti

Save_start:
	sei
	php

	a16i16()
	pha
	phx
	phy
	phb
	phd

	lda #$0000
	tcd

	a8()

	pha
	plb

	lda.l SS_PPU+INIDISP	;// Read INIDISP from PPU
	sta.l SSBASE+INIDISP	;// Store in shadow register
	
	lda #$88
	sta.w INIDISP
	
	lda.w RDNMI
	
	lda #$00
	sta.w NMITIMEN
	sta.w HDMAEN

Save_mapper_init:
	lda SS_ROMTYPE
	and #$F0
	cmp.b #ROM_SA1
	bne +
	jmp sa1_save_init
+

Save_mapper_init_end:

	ldx #$0000
-   
	lda.w $4300,x			;// Store DMA regs $4300-$4306 into shadow regs
	sta.l SSBASE+$4300,x
	inx
	cpx #$0007
	bne -
	
	sta SSADDR
	
	lda.b #'S'
	sta SSDATA
	lda.b #'N'
	sta SSDATA
	lda.b #'E'
	sta SSDATA
	lda.b #'S'
	sta SSDATA
	
	lda.b #$00				;// Reserved
	sta SSDATA
	sta SSDATA
	sta SSDATA
	sta SSDATA

   
	lda.b #SS_WRAM
	sta SSDATA

Save_stack:
	tsa
	sta SSDATA
	xba
	sta SSDATA

Save_wram: 
	lda #$00
	sta.w WMADDL
	sta.w WMADDM
	sta.w WMADDH
   
	SetupDMA((DMA_DIR_BA | DMA_FIXED_A | DMA_MODE_0), SSDATA, $80, 0)
	
	lda #$01
	sta $420B
	
	sta $420B
	
	lda SS_WMADDL			;// Load from shadow register
	sta.w WMADDL			;// Restore register
	sta SSDATA				;// Save register to save state
	
	lda SS_WMADDM
	sta.w WMADDM
	sta SSDATA
	
	lda SS_WMADDH
	sta.w WMADDH
	sta SSDATA

	
Save_vram:
	lda.b #SS_VRAM
	sta SSDATA
	
	lda.l SS_PPU+VMAIN		;// Store VRAM regs in temp registers
	sta.l SS_TEMP1			;// These will be overwritten below
	
	lda.l SS_PPU+VMADDL
	sta.l SS_TEMP2
	
	lda.l SS_PPU+VMADDH
	sta.l SS_TEMP3
	
	lda #$80
	sta.w VMAIN
	
	lda #$00
	sta.w VMADDL
	sta.w VMADDH
	
	lda VMDATALREAD			;// Dummy read
	lda VMDATAHREAD
	
	SetupDMA((DMA_DIR_BA | DMA_FIXED_A | DMA_MODE_1), SSDATA, $39, 0)
	
	lda #$01
	sta $420B
	
	lda.l SS_TEMP1			;// Restore VRAM regs
	sta.w VMAIN
	
	lda.l SS_TEMP2
	sta.w VMADDL
	
	lda.l SS_TEMP3
	sta.w VMADDH
	
Save_oam:
	lda.b #SS_OAM
	sta SSDATA
	
	lda.l SS_PPU+OAMADDL	;// Store OAM regs in temp registers
	sta.l SS_TEMP1
	
	lda.l SS_PPU+OAMADDH
	sta.l SS_TEMP2
	
	lda #$00
	sta.w OAMADDL
	sta.w OAMADDH
   
	SetupDMA((DMA_DIR_BA | DMA_FIXED_A | DMA_MODE_0), SSDATA, $38, 544)
   
	lda #$01
	sta $420B
	
	lda.l SS_TEMP1			;// Restore OAM regs
	sta.w OAMADDL
	
	lda.l SS_TEMP2
	sta.w OAMADDH
	
Save_cgram:
	lda.b #SS_CGRAM
	sta SSDATA
	
	lda.l SS_PPU+CGADD		;// Store CGRAM regs in temp registers
	sta.l SS_TEMP1
	
	lda.l SS_PPU+CGADD0
	sta.l SS_TEMP2

	lda #$00    
	sta.w CGADD
   
	SetupDMA((DMA_DIR_BA | DMA_FIXED_A | DMA_MODE_0), SSDATA, $3B, 512)
   
	lda #$01
	sta $420B   

	lda SS_TEMP1			;// Store CGRAM address
	sta SSDATA
	sta.w CGADD
	
	lda SS_TEMP2			;// Store CGRAM address LSB
	sta SSDATA
	xba
	
	lda.l SS_PPU+CGDATA		;// Store CGRAM latch value
	sta SSDATA
	
	xba
	bit #$01				;// Write latch value to CGDATA if LSB is 1
	beq +					;// This will restore the LSB of CGADD
	xba
	sta.w CGDATA
+

Save_aram:
	lda.b #SS_ARAM
	sta SSDATA
	
	sta SS_EXT_ADDR
   
	SetupDMA((DMA_DIR_BA | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_ARAM_DATA, 0)
   
	lda #$01
	sta $420B 
	
Save_dsp_regs:
	lda.b #SS_DPSREGS
	sta SSDATA
	
	sta SS_EXT_ADDR
   
	SetupDMA((DMA_DIR_BA | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_DSP_REGSD, 128+192)
   
	lda #$01
	sta $420B

Save_smp_regs:
	lda.b #SS_SMPREGS
	sta SSDATA
	
	sta SS_EXT_ADDR
   
	SetupDMA((DMA_DIR_BA | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_SMP_REGSD, 32)
   
	lda #$01
	sta $420B     
	
Save_ppu_regs1:
	lda.b #SS_PPUPREGS1
	sta SSDATA

	lda #$00				;// clear B register
	xba
	
	ldy #$0000
-    
	lda PPURegs1,y
	cmp.b #COLDATA2			;// Special cases
	beq +
	cmp.b #COLDATA3
	beq +
	bra ++
+
	tax
	lda.b #COLDATA			;// Store as COLDATA register number
	sta SSDATA
	txa
	bra Save_ppu_regs1_value
+
	sta SSDATA				;// Store register number in save state
	
	cmp #$FF
	beq Save_ppu_regs1_end

Save_ppu_regs1_value:
	cmp.b #INIDISP			;// Get INIDISP from Shadow register
	bne +
	lda.l SSBASE+INIDISP	;// Store INIDISP in shadow register
	bra ++

+	
	tax						;// Load byte destination in x
	lda.l SS_PPU+PPU_BASE,x	;// Load value from PPU register
+	
	sta SSDATA				;// Store register value in save state

	iny
	bra -
Save_ppu_regs1_end:

Save_ppu_regs2:
	lda.b #SS_PPUPREGS2
	sta SSDATA

	lda #$00				;// clear B register
	xba
	
	ldy #$0000
-    
	lda PPURegs2,y
	sta SSDATA				;// Store register in save state
	
	cmp #$FF
	beq Save_ppu_regs2_end
	
	tax						;// Load byte destination in x
	lda.l SS_PPU+PPU_BASE,x	;// Load value from PPU register
	sta SSDATA				;// Store register value in save state
	
	lda.l SS_PPU+PPU_HBASE,x	;// High byte
	sta SSDATA

	iny
	bra -
Save_ppu_regs2_end:

Save_mmio_regs:
	lda.b #SS_MMIOREGS
	sta SSDATA
	
	lda.l SSBASE+NMITIMEN
	sta SSDATA
	
	lda.l SSBASE+WRIO
	sta SSDATA
	
	lda.l SSBASE+WRMPYA
	sta SSDATA
	
	lda.l SSBASE+WRMPYB
	sta SSDATA
	
	lda.l SSBASE+WRDIVL
	sta SSDATA
	
	lda.l SSBASE+WRDIVH
	sta SSDATA
	
	lda.l SSBASE+WRDIVB
	sta SSDATA
	
	lda.l SSBASE+HTIMEL
	sta SSDATA
	
	lda.l SSBASE+HTIMEH
	sta SSDATA
	
	lda.l SSBASE+VTIMEL
	sta SSDATA
	
	lda.l SSBASE+VTIMEH
	sta SSDATA
	
	lda.l SSBASE+HDMAEN
	sta SSDATA
	
	lda.l SSBASE+MEMSEL
	sta SSDATA
	
	lda.l SS_WRDIVLAST
	sta SSDATA


Save_bsram:
	lda.l SS_BSRAMSIZE
	beq Save_bsram_end		;// Skip if Save ram size is 0
	
	xba
	lda.b #SS_BSRAM
	sta SSDATA
	
	lda.b #$00
	xba
		 
	cmp #$09				;// Size is max 8 for 256KB
	bcc +
	lda.b #$08
+

	sta SSDATA				;// Store ram size in save state
	
	tax						;// 1 << RAMSIZE for 1KB block count
	lda.b #$01
	a16i16()
-
	asl
	dex
	bne -
	
	a8i16()
	
	tax
	
	sta SS_EXT_ADDR

-
	SetupDMA((DMA_DIR_BA | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_BSRAM_DATA, 1024)

	lda #$01
	sta $420B 
	
	dex
	bne -
Save_bsram_end:

	lda SS_ROMTYPE
	tax
	and #$F0
	cmp.b #ROM_SA1
	bne +
	jmp sa1_save_regs_snes
+
	txa
	and.b #ROM_DSP_MASK
	cmp.b #ROM_DSP
	bne +
	jmp dspn_save_regs
+
	txa
	and #$F0
	cmp.b #ROM_GSU
	bne +
	jmp gsu_save_regs1
+

Save_mapper_end:

Save_dma_regs:
	lda.b #SS_DMAREGS
	sta SSDATA
	
	ldx #$0000
-
	lda.l SSBASE+$4300,x	;// First restore DMA regs $4300-$4306 from shadow regs
	sta.w $4300,x
	
	inx
	cpx #$0007
	bne -
	
	ldx #$0000
	
-
	lda.w $4300,x
	sta SSDATA
	
	lda.w $4301,x
	sta SSDATA
	
	lda.w $4302,x
	sta SSDATA
	
	lda.w $4303,x
	sta SSDATA
	
	lda.w $4304,x
	sta SSDATA
	
	lda.w $4305,x
	sta SSDATA
	
	lda.w $4306,x
	sta SSDATA
	
	lda.w $4307,x
	sta SSDATA
	
	lda.w $4308,x
	sta SSDATA
	
	lda.w $4309,x
	sta SSDATA
	
	lda.w $430A,x
	sta SSDATA
	
	lda.w $430B,x
	sta SSDATA
	
	a16()
	
	txa
	clc
	adc #$0010				;// Add $10 for next DMA channel regs
	tax
	
	a8()
	
	cpx #$0080
	bne -

	jmp Save_end
	

Load_start:
	sei

	a16i16()
	
	lda #$0000
	tcd

	a8()

	pha						;// Set Data bank to $00
	plb
	
	lda #$88
	sta.w INIDISP
	
	lda RDNMI
	
	lda #$00
	sta.w NMITIMEN
	sta.w HDMAEN
	
	sta SSADDR				;// Reset data addr and preload data
	
Load_mapper_init:
	lda SS_ROMTYPE
	and #$F0
	cmp.b #ROM_SA1
	bne +
	jmp sa1_load_init
+

Load_mapper_init_end:
	
-	
	lda SS_STATUS
	and.b #STATUS_BUSY
	bne -
	
	lda SSDATA
	lda SSDATA
	lda SSDATA
	lda SSDATA
	lda SSDATA
	lda SSDATA
	lda SSDATA
	lda SSDATA
	
	lda SSDATA				;// load block #
	
Load_stack:
	lda SSDATA
	xba
	lda SSDATA
	xba
	tas
	
Load_wram:
	lda #$00
	sta.w WMADDL
	sta.w WMADDM
	sta.w WMADDH
	
	SetupDMA((DMA_DIR_AB | DMA_FIXED_A | DMA_MODE_0), SSDATA, $80, 0)
	
	lda #$01
	sta.w $420B
	
	sta.w $420B
	
	lda SSDATA
	sta.w WMADDL
	
	lda SSDATA
	sta.w WMADDM
	
	lda SSDATA
	sta.w WMADDH

Load_vram:
	lda SSDATA				;// load block #
	
	lda #$80
	sta.w VMAIN
	
	lda #$00
	sta.w VMADDL
	sta.w VMADDH
	
	SetupDMA((DMA_DIR_AB | DMA_FIXED_A | DMA_MODE_1), SSDATA, $18, 0)
	
	lda #$01
	sta $420B  

Load_oam:
	lda SSDATA				;// load block #
	
	lda #$00
	sta.w OAMADDL
	sta.w OAMADDH
   
	SetupDMA((DMA_DIR_AB | DMA_FIXED_A | DMA_MODE_0), SSDATA, $04, 544)
   
	lda #$01
	sta $420B

Load_cgram:
	lda SSDATA				;// load block #
	
	lda #$00    
	sta.w CGADD
   
	SetupDMA((DMA_DIR_AB | DMA_FIXED_A | DMA_MODE_0), SSDATA, $22, 512)
   
	lda #$01
	sta $420B
	
	lda SSDATA
	sta CGADD				;// Restore CGRAM address
	
	lda SSDATA				;// Load CGRAM address LSB
	xba
	lda SSDATA				;// Load CGRAM latch value
	
	xba
	bit #$01				;// Write latch value to CGDATA if LSB is 1
	beq +					;// This will restore the LSB of CGADD
	xba
	sta CGDATA
+
	
	
Load_aram:
	lda SSDATA				;// load block #
	
	sta SS_EXT_ADDR
	
	SetupDMA((DMA_DIR_AB | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_ARAM_DATA, 0)
   
	lda #$01
	sta $420B
	
Load_dsp_regs:
	lda SSDATA				;// load block #
	
	sta SS_EXT_ADDR
	
	SetupDMA((DMA_DIR_AB | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_DSP_REGSD, 128+192)

	lda #$01
	sta $420B
	
Load_smp_regs:
	lda SSDATA				;// load block #
	
	sta SS_EXT_ADDR
	
	SetupDMA((DMA_DIR_AB | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_SMP_REGSD, 32)
   
	lda #$01
	sta $420B 
	
  
Load_ppu_regs1:
	lda SSDATA

	lda #$00				;// clear B register
	xba
	
-    
	lda SSDATA				;// Load register index
	tax
	
	cmp #$FF
	beq Load_ppu_regs1_end
	
	lda SSDATA				;// Load register value from save state
	
	cpx #$0000				;// Skip $2100 INIDISP for now
	bne +
	sta.l SSBASE+INIDISP	;// Store INIDISP in shadow register
	bra -
+
	sta.w PPU_BASE,x
 
	bra -
Load_ppu_regs1_end:

Load_ppu_regs2:
	lda SSDATA

	lda #$00				;// clear B register
	xba
	
-    
	lda SSDATA				;// Load register index
	tax
	
	cmp #$FF
	beq Load_ppu_regs2_end
	
	lda SSDATA				;// Load register value from save state
	sta.w PPU_BASE,x
	
	lda SSDATA				;// High byte
	sta.w PPU_BASE,x
 
	bra -
Load_ppu_regs2_end:

Load_mmio_regs:
	lda SSDATA
	
	lda SSDATA
	sta.l SSBASE+NMITIMEN
	
	lda SSDATA
	;//sta.w WRIO
	
	lda SSDATA
	sta.w WRMPYA
	
	lda SSDATA
	sta.l SSBASE+WRMPYB
	
	lda SSDATA
	sta.w WRDIVL
	
	lda SSDATA
	sta.w WRDIVH

	lda SSDATA
	sta.l SSBASE+WRDIVB
	
	lda SSDATA
	sta.w HTIMEL
	
	lda SSDATA
	sta.w HTIMEH
	
	lda SSDATA
	sta.w VTIMEL
	
	lda SSDATA
	sta.w VTIMEH
	
	lda SSDATA
	sta.l SSBASE+HDMAEN
	
	lda SSDATA
	sta.w MEMSEL
	
	lda SSDATA
	bit #$01				;// Write WRDIVB if WRDIVLAST is 1 else WRMPYB
	beq +
	lda.l SSBASE+WRDIVB		;// Start division
	sta.w WRDIVB
	bra ++
+
	lda.l SSBASE+WRMPYB		;// Start multiplication
	sta.w WRMPYB
+


Load_other:
	lda SSDATA				;// load block ID
	cmp.b #SS_BSRAM
	bne +
	jmp Load_bsram
+
	cmp.b #SS_SA1REGS1
	bne +
	jmp sa1_load_regs_snes
+
	cmp.b #SS_DSPNREGS
	bne +
	jmp dspn_load_regs
+
	cmp.b #SS_GSUREGS1
	bne +
	jmp gsu_load_regs1
+
	jmp Load_dma_regs
	

Load_bsram:
	lda.b #$00
	xba
	
	lda SSDATA
	
	tax						;// 1 << RAMSIZE for 1KB block count
	lda.b #$01
	a16i16()
-
	asl
	dex
	bne -
	
	a8i16()
	
	tax
	
	sta SS_EXT_ADDR
   
-   
	SetupDMA((DMA_DIR_AB | DMA_FIXED_A | DMA_MODE_0), SSDATA, SS_BSRAM_DATA, 1024)
   
	lda #$01
	sta $420B 
	
	dex
	bne -

Load_bsram_end:
	jmp Load_other

Load_dma_regs:
	;//lda SSDATA
	
	ldx #$0000
	
-
	lda SSDATA
	sta.w $4300,x
	
	lda SSDATA
	sta.w $4301,x
	
	lda SSDATA
	sta.w $4302,x
	
	lda SSDATA
	sta.w $4303,x
	
	lda SSDATA
	sta.w $4304,x
	
	lda SSDATA
	sta.w $4305,x
	
	lda SSDATA
	sta.w $4306,x
	
	lda SSDATA
	sta.w $4307,x
	
	lda SSDATA
	sta.w $4308,x
	
	lda SSDATA
	sta.w $4309,x
	
	lda SSDATA
	sta.w $430A,x
	
	lda SSDATA
	sta.w $430B,x
	
	a16()
	
	txa
	clc
	adc #$0010				;// Add $10 for next DMA channel regs
	tax
	
	a8()
	
	cpx #$0080
	bne - 
	
	jmp Load_end

Save_end:
	lda #$FF
	sta SSDATA
	
	sta SS_END
	
Load_end:
	
waitVBlankEnd:
- 
	lda HVBJOY				;// Wait until vblank flag is up
	bpl -
-    
	lda HVBJOY				;// Wait until flag is down
	bmi -
	
	ldy #$1FFF				;// This delay is for RTI to happen
-							;// a few lines before VBlank
	dey
	bne -
	
	lda SS_ROMTYPE
	and #$F0
	cmp.b #ROM_SA1
	bne +
	jmp sa1_finish
+
Mapper_finish:

	lda.l SSBASE+INIDISP
	sta.w INIDISP
	
	lda.l SSBASE+HDMAEN
	sta.w HDMAEN
	
	lda.l SSBASE+NMITIMEN
	sta.w NMITIMEN
	
	a16i16()
	pld
	plb
	ply
	plx
	pla

	plp
	
	jmp Return

	
PPURegs1:
	db $00, $01, $02, $03, $05, $06, $07, $08, $09, $0A, $0B, $0C
	db $15, $16, $17, $1A, $23, $24, $25, $26, $27, $28, $29, $2A
	db $2B, $2C, $2D, $2E, $2F, $30, $31, $32, $33, $40, $41
	db $FF
PPURegs1End:

PPURegs2:
	db $0D, $0E, $0F, $10, $11, $12, $13, $14
	db $1B, $1C, $1D, $1E, $1F, $20, $FF
PPURegs3End:

include "savestates_sa1.asm"
include "savestates_dspn.asm"
include "savestates_gsu.asm"
