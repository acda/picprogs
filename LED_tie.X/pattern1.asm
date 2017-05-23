

gen_pattern1:
	banksel 0

	; calc new pos, one drop/sec
	movf l_secondsL,0
	movwf l_Al
	movlw NUM_LEDS
	call multiply_8_8_16
	movf l_Ah,0
	bcf WREG,0
	movwf l_state+0

	movlw low bufferLED
	movwf FSR1L
	movlw high bufferLED
	movwf FSR1H


	; init loop
	movlw NUM_LEDS
	movwf ml_count
	clrf l_pos

_pat1__lop:

	movlw 0x01
	movwf ml_temp
	movf l_pos,0
	subwf l_state+0,0
	btfss STATUS,Z
	bra $+3
	movlw 0xFF
	movwf ml_temp

	movf ml_temp,0
	movwi FSR1++
	clrf WREG
	movwi FSR1++
	movwi FSR1++

	incf l_pos,1
	decf ml_count,1
	btfss STATUS,Z
	goto _pat1__lop


;	movlw low bufferLED
;	movwf FSR1L
;	movlw high bufferLED
;	movwf FSR1H
;	movf l_state+0,0
;	movwi 4[FSR1]
;	movlw 0
;	movwi 3[FSR1]
;	movwi 5[FSR1]
;	movf l_secondsL,0
;	movwi 7[FSR1]
;	movlw 0
;	movwi 6[FSR1]
;	movwi 8[FSR1]


	return



