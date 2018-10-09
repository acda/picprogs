

; "speaking robot" style red light.

PAT8_COL_R = 0xDD
PAT8_COL_G = 0x55
PAT8_COL_B = 0x44

gen_pattern8_rob_spk:
	banksel 0

	; clear
	movlw low bufferLED
	movwf FSR0L
	movlw high bufferLED
	movwf FSR0H

	movlw NUM_LEDS
	movwf ml_temp
_pat8__clear:
	movlw 0x00
	movwi FSR0++
	movwi FSR0++
	movwi FSR0++
	decfsz ml_temp,1
	bra _pat8__clear


	movlp high getSine8bitSigned_256circle
	lsrf l_secondsH,0
	rrf l_secondsL,0
	call getSine8bitSigned_256circle
	movwf l_Al
	movlp 0
	movlw #3
	call multiply_8_8_16
	; result range  0 .. 768-1
	lsrf l_Ah,1
	rrf l_Al,1
	movlw 0x80
	subwf l_Al,1
	movlw 0
	subwfb l_Ah,1
	; result range -128 .. 255
	btfss STATUS,Z
	clrf l_Al
	; now is clipped to 0..255. Mult with half length.
	movlw (NUM_LEDS>>1)
	call multiply_8_8_16


	; half 1
	movlw low (bufferLED+3*(NUM_LEDS>>1))
	movwf FSR0L
	movlw high (bufferLED+3*(NUM_LEDS>>1))
	movwf FSR0H
	movf l_Al,0
	movwf ml_temp
	btfsc STATUS,Z
	bra _pat8__skip
_pat8__lop1:
	movlw PAT8_COL_R
	movwi FSR0++
	movlw PAT8_COL_G
	movwi FSR0++
	movlw PAT8_COL_B
	movwi FSR0++
	decfsz ml_temp,1
	bra _pat8__lop1

	; half 2
	movlw low (bufferLED+3*(NUM_LEDS>>1))
	movwf FSR0L
	movlw high (bufferLED+3*(NUM_LEDS>>1))
	movwf FSR0H
	movf l_Al,0
	movwf ml_temp
_pat8__lop2:
	movlw PAT8_COL_B
	movwi --FSR0
	movlw PAT8_COL_G
	movwi --FSR0
	movlw PAT8_COL_R
	movwi --FSR0
	decfsz ml_temp,1
	bra _pat8__lop2
_pat8__skip:

	return

