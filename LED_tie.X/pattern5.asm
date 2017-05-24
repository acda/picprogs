

gen_pattern5:
	banksel 0

	; prepare buf.
	movlw low bufferLED
	movwf FSR1L
	movlw high bufferLED
	movwf FSR1H

	; init loop
	clrf l_pos

_pat5__lop:

	; in javascript sample:  ('state' is time, in 50ms steps)
	;  var col = hsv_2_rgb(1+state*0.0125-i*0.01,0.75,1);

	; time-component for colH.
	movf l_secondsH,0
	movwf ml_temp
	movf l_secondsL,0
	movwf l_Bh
	clrf l_Bl
	lsrf ml_temp,1
	rrf l_Bh,1
	rrf l_Bl,1
	lsrf ml_temp,1
	rrf l_Bh,1
	rrf l_Bl,1
	; pos-part
	movlw 12
	movwf l_Al
	movf l_pos,0
	call multiply_8_8_16
	movf l_Al,0
	addwf l_Bl,1
	movf l_Ah,0
	addwfc l_Bh,1

	movf l_Bh,0
	movwf l_colH
	movlw 0xC0
	movwf l_colS
	movlw 0xFF
	movwf l_colV
	call convert_HSV_to_RGB

	movlw l_colR
	movwi FSR1++
	movlw l_colG
	movwi FSR1++
	movlw l_colB
	movwi FSR1++

	incf l_pos,1
	movlw NUM_LEDS
	subwf l_pos,0
	btfss STATUS,C
	bra _pat5__lop


	return



