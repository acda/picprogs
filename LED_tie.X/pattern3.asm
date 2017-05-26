

; "Knight-Rider" style red light.

gen_pattern3:
	banksel 0

	; clear
	movlw low bufferLED
	movwf FSR0L
	movlw high bufferLED
	movwf FSR0H

	movlw NUM_LEDS
	movwf ml_temp
_pat3__clear:
	movlw 0x00
	movwi FSR0++
	movlw 0x00
	movwi FSR0++
	movlw 0x00
	movwi FSR0++
	decfsz ml_temp,1
	bra _pat3__clear

	movlw low bufferLED
	movwf FSR1L
	movlw high bufferLED
	movwf FSR1H



	movlp high getSine8bitSigned_256circle
	lsrf l_secondsH,0
	rrf l_secondsL,0
	call getSine8bitSigned_256circle
	movwf ml_temp
	movlp 0
	addlw 0x80 ; make unsigned
	movwf l_Al
	movlw NUM_LEDS-2
	call multiply_8_8_16


;	movlw NUM_LEDS
;	movwf l_Al
;	movf l_secondsL,0
;	call multiply_8_8_16
;	btfsc l_secondsH,0
;	bra $+6
;	movlw 0xFF
;	xorwf l_Al,1
;	xorwf l_Ah,1
;	movlw NUM_LEDS
;	addwf l_Ah,1


;	movlw 0x03
;	movwf l_Ah
;	movlw 0xC0
;	movwf l_Al
	movlw 0xF0
	movwf l_colR
	movlw 0x10
	movwf l_colG
	movwf l_colB
	call mix_in


;	movlw #0x10
;	movwf ml_temp
;	movlw 0xC0
;	movwf l_colR
;	movwf l_colG
;	movwf l_colB
;	call _blend_col



	return

