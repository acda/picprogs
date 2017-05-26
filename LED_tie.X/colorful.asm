
;====================================================================
	nop


; color from  l_colR/l_colG/l_colB  ->  pos in l_Al:l_Ah
; uses FSR0, ml_temp/ml_temp2, l_Ax, 6 bytes on stack
mix_in:
	; same some vars
	call start_stack
	movf l_Bl,0
	movwi --FSR0
	movf l_Bh,0
	movwi --FSR0
	movf ml_temp2,0
	movwi --FSR0
	movf ml_temp3,0
	movwi --FSR0
	movf FSR1L,0
	movwi --FSR0
	movf FSR1H,0
	movwi --FSR0
	call done_stack

	; prepare
	movf l_Al,0
	movwf l_Bl
	movf l_Ah,0
	movwf l_Bh
	movlw NUM_LEDS
	subwf l_Bh,0
	btfsc STATUS,C
	bra _mix_in__leave ; off end.


	; calc start led.
	movlw low bufferLED
	movwf FSR1L
	movlw high bufferLED
	movwf FSR1H

	lslf l_Bh,0
	addwf l_Bh,0
	addwf FSR1L,1
	movlw 0
	addwfc FSR1H,1


	; set first
	movf l_Bl,0
	sublw 0xFF
	movwf ml_temp
	call _blend_col
	; move on
	incf l_Bh,1
	movlw 3
	addwf FSR1L,1
	movlw 0
	addwfc FSR1H,1

	; intermediates?
	movlw NUM_LEDS
	subwf l_Bh,0
	btfsc STATUS,C
	bra _mix_in__leave ; off end.
	movf l_colR,0
	movwi FSR1++
	movf l_colG,0
	movwi FSR1++
	movf l_colB,0
	movwi FSR1++
	incf l_Bh,1

	; end-led
	movlw NUM_LEDS
	subwf l_Bh,0
	btfsc STATUS,C
	bra _mix_in__leave ; off end.
	movf l_Bl,0
	btfsc STATUS,Z
	bra _mix_in__leave ; off end.
	movwf ml_temp
	call _blend_col



_mix_in__leave:
	; restore lots
	call start_stack
	moviw FSR0++
	movwf FSR1H
	moviw FSR0++
	movwf FSR1L
	moviw FSR0++
	movwf ml_temp3
	moviw FSR0++
	movwf ml_temp2
	moviw FSR0++
	movwf l_Bh
	moviw FSR0++
	movwf l_Bl
	goto done_stack


; color in l_colR/l_colG/l_colB , blend with [FSR1]
; mix-grade in ml_temp. 0=min, 0xFF=full
; uses l_Ax and ml_temp,ml_temp2
_blend_col:
	; check input
	movf ml_temp,0
	sublw 0xFF
	btfsc STATUS,Z
	bra _blend_col__full
	movwf ml_temp
	; same some vars
	call start_stack
	movf l_Bl,0
	movwi --FSR0
	movf l_Bh,0
	movwi --FSR0
	movf ml_temp3,0
	movwi --FSR0
	movf ml_temp4,0
	movwi --FSR0
	call done_stack

	movf ml_temp,0
	movwf ml_temp4
	movlw 3
	movwf ml_temp3



_blend_col__lop:
	; existing color * (1-q)
	moviw 0[FSR1]
	movwf l_Al
	movf ml_temp4,0
	call multiply_8_8_16
	movwf l_Bl
	movf l_Ah,0
	movwf l_Bh
	; new color * q
	lslf ml_temp3,0
	brw
	nop
	nop
	movf l_colB,0
	bra $+4
	movf l_colG,0
	bra $+2
	movf l_colR,0
	movwf l_Al
	movf ml_temp4,0
	sublw 0
	call multiply_8_8_16
	addwf l_Bl,0
	movf l_Ah,0
	addwfc l_Bh,0
	movwi FSR1++
	;lop
	decfsz ml_temp3,1
	bra _blend_col__lop

	movlw #3
	subwf FSR1L,1
	movlw #0
	subwfb FSR1H,1


	; restore vars and return
	call start_stack
	moviw FSR0++
	movwf ml_temp4
	moviw FSR0++
	movwf ml_temp3
	moviw FSR0++
	movwf l_Bh
	moviw FSR0++
	movwf l_Bl
	goto done_stack



_blend_col__full:
	movf l_colR,0
	movwi 0[FSR1]
	movf l_colG,0
	movwi 1[FSR1]
	movf l_colB,0
	movwi 2[FSR1]
	return





convert_HSV_to_RGB:
	; convert HSV ...
	; input: in l_colH/l_colS/l_colV
	; output: in l_colR/l_colG/l_colB
	; uses
	banksel 0
	; same some vars
;	call start_stack
;	movf l_Cl,0
;	movwi --FSR0
;	movf l_Ch,0
;	movwi --FSR0
;	call done_stack

	; calc Cx := 6*H
	clrf l_Ch
	lslf l_colH,0
	movwf l_Cl
	rlf l_Ch,1
	movf l_colH,0
	addwf l_Cl,1
	movlw 0
	addwfc l_Ch,1
	lslf l_Cl,1
	rlf l_Ch,1
	movf l_Ch,0
	brw
	bra hue0
	bra hue1
	bra hue2
	bra hue3
	bra hue4
	bra hue5
hue0:
	movlw 0xFF
	movwf l_colR
	movf l_Cl,0
	movwf l_colG
	clrf l_colB
	bra hueDone
hue1:
	movf l_Cl,0
	sublw 0xFF
	movwf l_colR
	movlw 0xFF
	movwf l_colG
	clrf l_colB
	bra hueDone
hue2:
	clrf l_colR
	movlw 0xFF
	movwf l_colG
	movf l_Cl,0
	movwf l_colB
	bra hueDone
hue3:
	clrf l_colR
	movf l_Cl,0
	sublw 0xFF
	movwf l_colG
	movlw 0xFF
	movwf l_colB
	bra hueDone
hue4:
	movf l_Cl,0
	movwf l_colR
	clrf l_colG
	movlw 0xFF
	movwf l_colB
	bra hueDone
hue5:
	movlw 0xFF
	movwf l_colR
	clrf l_colG
	movf l_Cl,0
	sublw 0xFF
	movwf l_colB
hueDone:
				bra _hsv__exit
	; do saturation
	movf l_colS,0
	btfsc STATUS,Z
	incf l_colS,1
	; sat R
	movf l_colR,0
	movwf l_Al
	movf l_colS,0
	call multiply_8_8_16
	movf l_colS,0
	sublw 0
	addwf l_Ah,0
	movwf l_colR
	; sat G
	movf l_colG,0
	movwf l_Al
	movf l_colS,0
	call multiply_8_8_16
	movf l_colS,0
	sublw 0
	addwf l_Ah,0
	movwf l_colG
	; sat B
	movf l_colB,0
	movwf l_Al
	movf l_colS,0
	call multiply_8_8_16
	movf l_colS,0
	sublw 0
	addwf l_Ah,0
	movwf l_colB

	; do V (brightness)
	movf l_colR,0
	movwf l_Al
	movf l_colV,0
	call multiply_8_8_16
	movf l_Ah,0
	movwf l_colR
	movf l_colG,0
	movwf l_Al
	movf l_colV,0
	call multiply_8_8_16
	movf l_Ah,0
	movwf l_colG
	movf l_colB,0
	movwf l_Al
	movf l_colV,0
	call multiply_8_8_16
	movf l_Ah,0
	movwf l_colB

_hsv__exit:
	; restore vars and return
;	call start_stack
;	moviw FSR0++
;	movwf l_Ch
;	moviw FSR0++
;	movwf l_Cl
;	goto done_stack
	return

