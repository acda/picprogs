
; white walking light.

PAT6_LEVEL = 0x77  ; was 0xB0

gen_pattern6:
	banksel 0

	; calc new state, two blinkcycles/sec
	lslf l_secondsL,0
	movwf ml_temp

	movlw low bufferLED
	movwf FSR1L
	movlw high bufferLED
	movwf FSR1H


	; init loop
	clrf l_pos

_pat6__lop:
	movlw PAT6_LEVEL
	btfss ml_temp,7
	movlw 0

	movwi FSR1++
	movwi FSR1++
	movwi FSR1++

	incf l_pos,1
	movlw NUM_LEDS
	subwf l_pos,0
	btfss STATUS,C
	goto _pat6__lop


	return



