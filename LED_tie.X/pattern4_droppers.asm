
; state+0: last-timestamp  [0:8]
; state+1: up to five 'droppers'
;
;   +0 posL
;   +1 posH
;   +2 speedL (low only for acceleration)
;   +3 speed  [5:11]
;   +4 <unused>
;

PAT4_NUM_DROPPERS = 3


; white droppers

gen_pattern4:
	banksel 0
	; calc timestep
	movf l_state+0,0
	subwf l_secondsL,0
	addwf l_state+0,1
	; have deltatime.
	movwf ml_temp3

	; clear
	movlw low bufferLED
	movwf FSR0L
	movlw high bufferLED
	movwf FSR0H

	movlw NUM_LEDS
	movwf ml_temp
_pat4__clear:
	movlw 0x00
	movwi FSR0++
	movlw 0x00
	movwi FSR0++
	movlw 0x00
	movwi FSR0++
	decfsz ml_temp,1
	bra _pat4__clear

	; set up loop
	clrf ml_temp4
_pat4__loop:
	; prepare FSR for dropper #.
	; l_state + 1 + 5*# .
	lslf ml_temp4,0
	lslf WREG,0
	addwf ml_temp4,0
	addlw l_state+1
	movwf FSR0L
	clrf FSR0H
	; mult speed*dT
	moviw 3[FSR0]
	movwf l_Al
	btfsc STATUS,Z
	bsf l_Al,3+2 ; do not allow speed of zero.
	movf ml_temp3,0 ; dT [0:8]
	call multiply_8_8_16
	; A is pos-step [5:11]
	; shift and add to pos.
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	moviw 0[FSR0]
	addwf l_Al,0
	movwi 0[FSR0]
	moviw 1[FSR0]
	addwfc l_Ah,0
	movwi 1[FSR0]
	movwf ml_temp
	; check limit
	movlw NUM_LEDS+5
	subwf ml_temp,0
	btfss STATUS,C
	bra _pat4__in_limit
	; out of limits.
	; restart, choose new speed
	movlw 0
	movwi 0[FSR0]
	movwi 1[FSR0]
	movwi 2[FSR0]
	; choose new speed
	call rnd
	andlw 0x7F
	addlw 0x40
	movwi 3[FSR0]
_pat4__in_limit:
	; put LED
	movlw 0x90
	movwf l_colR
	movlw 0x90
	movwf l_colG
	movlw 0xE0
	movwf l_colB
	moviw 0[FSR0]
	movwf l_Al
	moviw 1[FSR0]
	movwf l_Ah
	movlw 3
	call mix_in


	incf ml_temp4
	movlw PAT4_NUM_DROPPERS
	subwf ml_temp4,0
	btfss STATUS,C
	bra _pat4__loop



	return




