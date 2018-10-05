
; hue-cycle.

PAT7_INC = (0xFFFF/NUM_LEDS)

gen_pattern7_huescroll:
	banksel 0

	; prepare buf.
	movlw low bufferLED
	movwf FSR1L
	movlw high bufferLED
	movwf FSR1H

	; calc position and increment
;	lslf l_secondsL,0
	movf l_secondsL,0
	movwf l_state+1   ; cycle. 0..0xFF
	clrf l_state+0

	; init loop
	clrf l_pos

_pat7__lop:

	; in javascript sample:  ('state' is time, in 50ms steps)
	;  var col = hsv_2_rgb(1+state*0.0125-i*0.01,0.75,1);

	; Hue is just the value from l_state+1

	movf l_state+1,0
	movwf l_colH
	movlw 0x99
	movwf l_colS
	movlw 0xFF
	movwf l_colV
	call convert_HSV_to_RGB

	movf l_colR,0
	movwi FSR1++
	movf l_colG,0
	movwi FSR1++
	movf l_colB,0
	movwi FSR1++

	; increment to cycle the colors
	movlw low PAT7_INC
	addwf l_state+0,1
	movlw high PAT7_INC
	addwf l_state+1,1

	incf l_pos,1
	movlw NUM_LEDS
	subwf l_pos,0
	btfss STATUS,C
	bra _pat7__lop


	return

