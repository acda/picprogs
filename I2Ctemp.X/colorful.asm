
;====================================================================

; calc pattern
calcPattern:
	; fill all white/blue. By temp, set a bright red mark.
	; below, fade out the red, back to white/blue
	banksel 0
	clrf ml_temp
	clrf l_Al
	clrf l_Ah
	btfss l_TempValid,0
	bra $+6
	incf ml_temp,1
	movf l_TempAl,0
	addwf l_Al,1
	movf l_TempAh,0
	addwfc l_Ah,1
	btfss l_TempValid,1
	bra $+6
	incf ml_temp,1
	movf l_TempBl,0
	addwf l_Al,1
	movf l_TempBh,0
	addwfc l_Ah,1
	movf ml_temp,0
	btfsc STATUS,Z
	goto damnHaveNoTemp
	btfss ml_temp,1
	bra $+3
	asrf l_Ah,1
	rrf l_Al,1
	bra haveTemper

damnHaveNoTemp:
	movlw 0x00	; have none? set -32deg
	movwf l_Al
	movlw 0xFD
	movwf l_Ah

haveTemper:

	; have temperature.
	; subtrace lower bound    (fridge: -2 , room 16)
	;   for room: subtract 15.5  0x00F8  , for fridge: add 0x0020

	movlw 0x20	; + 2.0 deg
	addwf l_Al,1
	movlw 0x00
	addwfc l_Ah,1

;	movlw 0xF8	; - 15.5 deg
;	subwf l_Al,1
;	movlw 0x00
;	subwfb l_Ah,1

	btfss l_Ah,7
	bra $+3
	clrf l_Al
	clrf l_Ah

	; wanted range is 13.  do *32/(2*13.5).
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	movlw .13*2+1
	call divide_16_8

	movwf l_Dl
	call putHEX


	banksel 0
	; prepare loop
	clrf l_pos
	movlw low bufferLED
	movwf FSR1L
	movlw high bufferLED
	movwf FSR1H
loopFill:
	banksel 0
	; calc X. pos on stripe, 0.0 .. 1.0
	movf l_pos,0
	movwf l_Ah
	clrf l_Al
	movlw NUM_LEDS
	call divide_16_8
	movwf l_X

	; sin 2.5*X + 0.5*T
	movlp high getSine8bitSigned_256circle
	lslf l_X,0
	movwf ml_temp
	lsrf l_X,0
	addwf ml_temp,1
	lsrf l_secondsH,0
	rrf l_secondsL,0
	addwf ml_temp,0
	call getSine8bitSigned_256circle
	movwf ml_temp3
	clrf ml_temp4
	btfsc ml_temp3,7
	decf ml_temp4,1

	; sin 4*X + T, other direction
	lslf l_X,0
	lslf WREG,0
	movwf ml_temp
	movf l_secondsL,0
	subwf ml_temp,0
	call getSine8bitSigned_256circle
	movlp 0
	addwf ml_temp3,1
	btfsc STATUS,C
	incf ml_temp4,1
	btfsc WREG,7
	decf ml_temp4,1

	; ml_temp3/4 is now result of sin()+sin()
	; multiply with 0.11 (*28, >>8)a
	lslf ml_temp3,1
	rlf ml_temp4,1
	lslf ml_temp3,1
	rlf ml_temp4,1
	lslf ml_temp3,0
	movwf ml_temp
	rlf ml_temp4,0
	movwf ml_temp2
	lslf ml_temp,1
	rlf ml_temp2,1
	lslf ml_temp,1
	rlf ml_temp2,1
	movf ml_temp3,0
	subwf ml_temp,1
	movf ml_temp4,0
	subwfb ml_temp2,1
	; now value in ml_temp/ml_temp2 is from -28 .. 28  [8:8]
	movf ml_temp2,0
	movwf l_colH
	; l_colH is now 0.11 * (sin()+sin())

	; S = 0.6
	movlw 0xBB		; Saturation [0:8]
	movwf l_colS
	; V = 0.75
	movlw 0xEE
	movwf l_colV

	; temp here is full range, already scaled
	movf l_Dl,0

;	; scale to reduce range to 12 degrees
;	movlw 0x60
;	subwf l_Dl,0
;	btfss STATUS,C
;	bra $+3
;	movlw 0x5F
;	movwf l_Dl
;	movf l_Dl,0
;	movwf l_Ah
;	clrf l_Al
;	movlw 0x60
;	call divide_16_8

	movwf l_tempmark
	; l_tempmark is now temperature, comparable with l_X.

	movf l_X,0
	subwf l_tempmark,0
	btfss STATUS,C
	bra overMark
	; is below mark.
	; calc  1 / (8*(tempm-X)+1)
	; calc  0.125 / ((tempm-X)+0.125)

	clrf l_Ch
	addlw 0x60
	movwf l_Cl
	btfsc STATUS,C
	incf l_Ch,1			; C[8:8] is now  0.125 .. 1.125
	; need to div   0.125  /  C[8:8]
	movlw 0x30
	movwf l_Ah
	clrf l_Al
	; div   A[1:15] / C[8:8]  ->  tempmark[1:7]
	btfss l_Ch,0
	bra $+5
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ch,1
	rrf l_Cl,1
	movf l_Cl,0
	call divide_16_8
	; max result is 0x80, is [1:7]
	movwf l_tempmark

	; H = H*(1.0-tempmark) + 0.66667
	; l_colH is currently signed value.
	movf l_colH,0
	btfsc l_colH,7
	sublw 0
	movwf l_Al
	movf l_tempmark,0
	sublw 0x80
	call multiply_8_8_16		;[0:8] * [1:7] -> [1:15]
	btfss l_colH,7	; sign...
	bra $+8
	clrf ml_temp
	movf l_Al,0
	sublw 0
	movwf l_Al
	movf l_Ah,0
	subwfb ml_temp,0
	movwf l_Ah

	lslf l_Al,1
	rlf l_Ah,1
	; blue is 0xAAAB.  10% from blue over to green is 0xA222. Green is 0x5555.
	movlw 0x22
	addwf l_Al,1
	movlw 0xA2
	addwf l_Ah,0
	movwf l_colH

	; H += 0.33333 * tempmark
	movf l_tempmark,0
	movwf l_Al
	movlw 0xBC
	call multiply_8_8_16		;[1:7] * [-1:9]
	movf l_Ah,0
	addwf l_colH,1

	; S = 0.6+0.33333 * tempmark
	movlw 0x98		; 0.6 [0:8]
	addwf l_Ah,0
	movwf l_colS

	bra haveHSV

overMark:
	movlw 0xAB
	addwf l_colH,1
	; S = 0.6
	movlw 0x98		; 0.6 [0:8]
	movwf l_colS

haveHSV:
	; convert HSV ...
	; C = 6*H
	clrf l_Ch
	lslf l_colH,0
	movwf l_Cl
	btfsc STATUS,C
	incf l_Ch,1
	movf l_colH,0
	addwf l_Cl,1
	btfsc STATUS,C
	incf l_Ch,1
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

	; convert to 5:6:5 , -> FSR1++
	movf l_colR,0
	addlw 0x04
	btfsc STATUS,C
	decf WREG,0
	andlw 0xF8
	movwf ml_temp
	movf l_colG,0
	addlw 0x02
	btfsc STATUS,C
	decf WREG,0
	andlw 0xFC
	movwf ml_temp2
	lsrf WREG,0
	lsrf WREG,0
	lsrf WREG,0
	lsrf WREG,0
	lsrf WREG,0
	iorwf ml_temp,0
	movwi FSR1++
	lslf ml_temp2,1
	lslf ml_temp2,1
	lslf ml_temp2,1
	movf l_colB,0
	addlw 0x04
	btfsc STATUS,C
	decf WREG,0
	lsrf WREG,0
	lsrf WREG,0
	lsrf WREG,0
	iorwf ml_temp2,0
	movwi FSR1++

	; uart buffers
	call testTX
;	call testRX

	; timer tick
	banksel 0
	btfss PIR1,1		; TMR2IF
	bra $+3
	bcf PIR1,1		; TMR2IF
	incf ml_timeCount,1

	banksel 0

	; done. loopcount
	incf l_pos,1
	movlw NUM_LEDS
	subwf l_pos,0
	btfss STATUS,C
	goto loopFill


