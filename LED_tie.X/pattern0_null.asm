
; all off. Null pattern.

gen_pattern0_null:
	banksel 0

	movlw low bufferLED
	movwf FSR1L
	movlw high bufferLED
	movwf FSR1H

	; init loop
	movlw NUM_LEDS
	movwf ml_count
	clrf l_pos

_pat0__lop:

	clrf WREG
	movwi FSR1++
	movwi FSR1++
	movwi FSR1++

	incf l_pos,1
	decf ml_count,1
	btfss STATUS,Z
	goto _pat0__lop

	return



