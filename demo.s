.segment "HEADER"
	.byte "NES"		;identification string
	.byte $1A
	.byte $02		;amount of PRG ROM in 16K units
	.byte $01		;amount of CHR ROM in 8K units
	.byte $00		;mapper and mirroing
	.byte $00, $00, $00, $00
	.byte $00, $00, $00, $00, $00
.segment "ZEROPAGE"
player_x:	.RES 1	;reserves 1 byte of memory for player's x coordinate
player_y:	.RES 1  ;same but for y
player_is_walking: .byte 0  ;not walking = 0	walking = 1
player_walk_frame_counter: .byte 0 ;stores the frame of the player walk animation

.segment "STARTUP"

RESET:
	SEI 		;disables interupts
	CLD			;turn off decimal mode
	
	LDX #%1000000	;disable sound IRQ
	STX $4017
	LDX #$00
	STX $4010		;disable PCM
	
	;initialize the stack register
	LDX #$FF
	TXS 		;transfer x to the stack
	
	; Clear PPU registers
	LDX #$00
	STX $2000
	STX $2001
	
	;WAIT FOR VBLANK
:
	BIT $2002
	BPL :-
	
	;CLEARING 2K MEMORY
	TXA
CLEARMEMORY:		;$0000 - $07FF
	STA $0000, X
	STA $0100, X
	STA $0300, X
	STA $0400, X
	STA $0500, X
	STA $0600, X
	STA $0700, X
		LDA #$FF
		STA $0200, X
		LDA #$00
	INX
	CPX #$00
	BNE CLEARMEMORY

	;WAIT FOR VBLANK
:
	BIT $2002
	BPL :-
	
	;SETTING SPRITE RANGE
	LDA #$02
	STA $4014
	NOP
	
	LDA #$3F	;$3F00
	STA $2006
	LDA #$00
	STA $2006
	
	LDX #$00
LOADPALETTES:
	LDA PALETTEDATA, X
	STA $2007
	INX
	CPX #$20
	BNE LOADPALETTES

;LOADING SPRITES
	LDX #$00
LOADSPRITES:
	LDA SPRITEDATA, X
	STA $0200, X
	INX
	CPX #$20	;16bytes (4 bytes per sprite, 8 sprites total)
	BNE LOADSPRITES	

;LOADING BACKGROUND
	
LOADBACKGROUND:
	LDA $2002		;read PPU status to reset high/low latch
	LDA #$20
	STA $2006
	LDA #$00
	STA $2006
	LDX #$00
LOADBACKGROUNDP1:
	LDA BACKGROUNDDATA, X
	STA $2007
	INX
	CPX #$00
	BNE LOADBACKGROUNDP1
LOADBACKGROUNDP2:
	LDA BACKGROUNDDATA+256, X
	STA $2007
	INX
	CPX #$00
	BNE LOADBACKGROUNDP2

;LOAD BACKGROUND PALETTEDATA
	LDA #$23	;$23C0
	STA $2006
	LDA #$C0
	STA $2006
	LDX #$00
LOADBACKGROUNDPALETTEDATA:
	LDA BACKGROUNDPALETTEDATA, X
	STA $2007
	INX
	CPX #$20
	BNE LOADBACKGROUNDPALETTEDATA

	;RESET SCROLL
	LDA #$00
	STA $2005
	STA $2005	
		
;ENABLE INTERUPTS
	CLI
	
	LDA #%10010000
	STA $2000			;WHEN VBLANK OCCURS CALL NMI
	
	LDA #%00011110		;show sprites and background
	STA $2001

	; INITIALIZE VARIABLES
	LDA $0203
	STA player_x
	LDA $0200
	STA player_y
	
	INFLOOP:
		JMP INFLOOP

NMI: ; PPU Update Loop -- gets called every frame

	LDA #$02	;LOAD SPRITE RANGE
	STA $4014

	; used for animation -- by default the player is not walking
	; if the player is walking, the flag will be set when input is read
	LDA #$00
	STA player_is_walking ; mark the player as not walking

	;	----------	CONTROLLER INPUTS	-----------
	;	controller input sequence: 
	;	A, B, Select, Start, Up, Down, Left, Right
	LatchController: 
		LDA #$01
		STA $4016
		LDA #$00		; what the fuck? this is necessary btw
		STA $4016       ; tell both the controllers to latch buttons

	ReadA:
		LDA $4016
		AND #%00000001
		BNE DoA
		JMP ReadADone
	DoA:
		;TODO -- add attack action trigger
	ReadADone:

	ReadB:
		LDA $4016
		AND #%00000001
		BNE DoB
		JMP ReadBDone
	DoB:
		;TODO -- add attack action trigger
	ReadBDone:

	ReadSelect:
		LDA $4016
		AND #%00000001
		BNE DoSelect
		JMP ReadSelectDone
	DoSelect:
		;unimplemented -- no effect on game
	ReadSelectDone:

	ReadStart:
		LDA $4016
		AND #%00000001
		BNE DoStart
		JMP ReadStartDone
	DoStart:
		;unimplemented -- no effect on game
	ReadStartDone:

	ReadUp:
		LDA $4016
		AND #%00000001
		BNE DoUp
		JMP ReadUpDone
	DoUp:
		LDA #$01
		STA player_is_walking ; mark the player as walking

		LDA player_y ; get player_y into A
		STA $0200 ; update player_y in the sprite data
		TAX
		DEX ; moves the player up
		STX player_y ; update our player_y variable
	ReadUpDone:

	ReadDown:
		LDA $4016
		AND #%00000001
		BNE DoDown
		JMP ReadDownDone
	DoDown:
		LDA #$01
		STA player_is_walking ; mark the player as walking

		LDA player_y ; get player_y into A
		STA $0200 ; update player_y in the sprite data
		TAX
		INX ; moves the player down
		STX player_y ; update our player_y variable
	ReadDownDone:
	
	ReadLeft:
		LDA $4016
		AND #%00000001
		BNE DoLeft
		JMP ReadLeftDone
	DoLeft:
		LDA #$01
		STA player_is_walking ; mark the player as walking

		LDA player_x ; get player_x into A
		STA $0203 ; update player_x in the sprite data
		TAX
		DEX ; moves the player left
		STX player_x ; update our player_x variable
		
		; make the player face left
		LDA $0202 ; get attributes for flipping horizontally
		ORA #%01000000
		STA $0202 ; write back after ensuring sprite flip horizontal bit is 1. other bits are preserved.
	ReadLeftDone:

	ReadRight:
		LDA $4016
		AND #%00000001
		BNE DoRight
		JMP ReadRightDone
	DoRight:
		LDA #$01
		STA player_is_walking ; mark the player as walking

		LDA player_x ; get player_x into A
		STA $0203 ; update player_x in the sprite data
		TAX
		INX ; moves the player right
		STX player_x ; update our player_x variable

		; make the player face right
		LDA $0202 ; get attributes for flipping horizontally
		AND #%10111111
		STA $0202 ; write back after ensuring sprite flip horizontal bit is 0. other bits are preserved.
	ReadRightDone:

	; set the player animation frames
	LDA player_is_walking
	BEQ player_idle_animation
	player_walking_animation:
		; update the frame counter
		LDX player_walk_frame_counter
		INX
		STX player_walk_frame_counter
		TXA

		; A >> 3
		; animation changes frame every 8 real frames
		LSR
		LSR
		LSR

		AND #%00000011
		CMP #$02
		BEQ player_walking_frame_2
		AND #%00000001
		CMP #$01
		BEQ player_walking_frame_1
		JMP player_walking_frame_0

		player_walking_frame_0:
			LDA #$00 ; pick frame 0
			STA $0201 ; update the sprite
			JMP player_animation_done

		player_walking_frame_1:
			LDA #$01 ; pick frame 0
			STA $0201 ; update the sprite
			JMP player_animation_done

		player_walking_frame_2:
			LDA #$02 ; pick frame 0
			STA $0201 ; update the sprite
			JMP player_animation_done

	player_idle_animation:
		LDA #$00 
		STA player_walk_frame_counter ; reset the walk animation
		STA $0201 ; reset the sprite to idle position
	player_animation_done:

	RTI

PALETTEDATA:
	.byte $2E, $27, $17, $15, 	$2E, $05, $00, $20, 	$2E, $05, $00, $20, 	$2E, $05, $00, $20 	;background palettes
	.byte $2E, $05, $00, $20, 	$2E, $20, $07, $3B, 	$2E, $20, $2C, $1C, 	$00, $3C, $2C, $1C 	;sprite palettes

SPRITEDATA:
;$0200 - The Y coordinate of the sprite on screen
;$0201 - The Tile Index of the sprite from the Pattern Table, allowing you to pick which tile to use for that sprite.
;$0202 - The Attribute Table of the sprite. 
;$0203 - The X coordinate of the sprite on screen
;... continues for the rest of the sprites

; ATTRIBUTE TABLE
;Y, SPRITE NUM, attributes, X
;76543210
;||||||||
;||||||++- Palette (4 to 7) of sprite
;|||+++--- Unimplemented
;||+------ Priority (0: in front of background; 1: behind background)
;|+------- Flip sprite horizontally
;+-------- Flip sprite vertically

	; $0200
	.byte $80, $00, $00000000, $60 ; player
	; $0204
	;...

BACKGROUNDDATA:	;512 BYTES
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $01,$02,$03,$04,$05,$06,$07,$02,$03,$04,$05,$06,$07,$02,$03,$04,$05,$06,$07,$02,$03,$04,$05,$06,$07,$02,$03,$04,$05,$06,$07,$08
	.byte $11,$12,$13,$14,$15,$16,$17,$12,$13,$14,$15,$16,$17,$12,$13,$14,$15,$16,$17,$12,$13,$14,$15,$16,$17,$12,$13,$14,$15,$16,$17,$18
	.byte $21,$22,$23,$24,$25,$26,$27,$22,$23,$24,$25,$26,$27,$22,$23,$24,$25,$26,$27,$22,$23,$24,$25,$26,$27,$22,$23,$24,$25,$26,$27,$28
	.byte $31,$32,$33,$34,$35,$36,$37,$32,$33,$34,$35,$36,$37,$32,$33,$34,$35,$36,$37,$32,$33,$34,$35,$36,$37,$32,$33,$34,$35,$36,$37,$38
	.byte $41,$42,$43,$44,$45,$46,$47,$42,$43,$44,$45,$46,$47,$42,$43,$44,$45,$46,$47,$42,$43,$44,$45,$46,$47,$42,$43,$44,$45,$46,$47,$48
	.byte $51,$52,$53,$54,$55,$56,$57,$52,$53,$54,$55,$56,$57,$52,$53,$54,$55,$56,$57,$52,$53,$54,$55,$56,$57,$52,$53,$54,$55,$56,$57,$58
	.byte $09,$0A,$00,$00,$00,$00,$09,$0A,$00,$00,$00,$00,$09,$0A,$00,$00,$00,$00,$09,$0A,$00,$00,$00,$00,$09,$0A,$00,$00,$00,$00,$09,$0A
	.byte $19,$1A,$00,$00,$00,$00,$19,$1A,$00,$00,$00,$00,$19,$1A,$00,$00,$00,$00,$19,$1A,$00,$00,$00,$00,$19,$1A,$00,$00,$00,$00,$19,$1A
	.byte $29,$2A,$00,$00,$00,$00,$29,$2A,$00,$00,$00,$00,$29,$2A,$00,$00,$00,$00,$29,$2A,$00,$00,$00,$00,$29,$2A,$00,$00,$00,$00,$29,$2A
	.byte $39,$3A,$00,$00,$00,$00,$39,$3A,$00,$00,$00,$00,$39,$3A,$00,$00,$00,$00,$39,$3A,$00,$00,$00,$00,$39,$3A,$00,$00,$00,$00,$39,$3A
	.byte $49,$4A,$00,$00,$00,$00,$49,$4A,$00,$00,$00,$00,$49,$4A,$00,$00,$00,$00,$49,$4A,$00,$00,$00,$00,$49,$4A,$00,$00,$00,$00,$49,$4A
	.byte $59,$5A,$00,$00,$00,$00,$59,$5A,$00,$00,$00,$00,$59,$5A,$00,$00,$00,$00,$59,$5A,$00,$00,$00,$00,$59,$5A,$00,$00,$00,$00,$59,$5A
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

BACKGROUNDPALETTEDATA:	;32 bytes
	.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	
.segment "VECTORS"
	.word NMI
	.word RESET
	; specialized hardware interurpts
.segment "CHARS"
	.incbin "rom.chr"
