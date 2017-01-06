

SBUS_VAL_D_LOW  = 0x00CD	; 10%
SBUS_VAL_D_HIGH = 0x0733	; 90%


decodeSbusFrame:
	; FSR1 points to decoded data
	; input taken from 25-byte buffer at l_framBuf1

	banksel l_framBuf1
	movf l_framBuf1,0
	sublw 0x0F
	btfss STATUS,Z
	retlw 0
;	movf l_framBuf1+.24,0
;	btfss STATUS,Z
;	retlw 0
	movf l_framBuf1+.23,0
	andlw 0xF0
	btfss STATUS,Z
	retlw 0

	;channel #0, bytes 1..2 , shift 0 bits.
	movf l_framBuf1+.1,0
	movwf l_Al
	movf l_framBuf1+.2,0
	movwf l_Ah
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #1, bytes 2..3 , shift 3 bits.
	lsrf l_framBuf1+.2,0
	movwf l_Al
	rrf l_framBuf1+.3,0
	movwf l_Ah
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #2, bytes 3..5 , shift 6 bits.
	lslf l_framBuf1+.3,0
	movwf ml_temp
	rlf l_framBuf1+.4,0
	movwf l_Al
	rlf l_framBuf1+.5,0
	movwf l_Ah
	lslf ml_temp,1
	rlf l_Al,1
	rlf l_Ah,1
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #3, bytes 5..6 , shift 1 bits.
	lsrf l_framBuf1+.5,0
	movwf l_Al
	rrf l_framBuf1+.6,0
	movwf l_Ah
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #4, bytes 6..7 , shift 4 bits.
	lsrf l_framBuf1+.6,0
	movwf l_Al
	rrf l_framBuf1+.7,0
	movwf l_Ah
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #5, bytes 7..9 , shift 7 bits.
	lslf l_framBuf1+.7,0
	rlf l_framBuf1+.8,0
	movwf l_Al
	rlf l_framBuf1+.9,0
	movwf l_Ah
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #6, bytes 9..10 , shift 2 bits.
	lsrf l_framBuf1+.9,0
	movwf l_Al
	rrf l_framBuf1+.10,0
	movwf l_Ah
	lsrf l_Ah,1
	rrf l_Al,1
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #7, bytes 10..11 , shift 5 bits.
	lsrf l_framBuf1+.10,0
	movwf l_Al
	rrf l_framBuf1+.11,0
	movwf l_Ah
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #8, bytes 12..13 , shift 0 bits.
	movf l_framBuf1+.12,0
	movwf l_Al
	movf l_framBuf1+.13,0
	movwf l_Ah
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #9, bytes 13..14 , shift 3 bits.
	lsrf l_framBuf1+.13,0
	movwf l_Al
	rrf l_framBuf1+.14,0
	movwf l_Ah
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #10, bytes 14..16 , shift 6 bits.
	lslf l_framBuf1+.14,0
	movwf ml_temp
	rlf l_framBuf1+.15,0
	movwf l_Al
	rlf l_framBuf1+.16,0
	movwf l_Ah
	lslf ml_temp,1
	rlf l_Al,1
	rlf l_Ah,1
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #11, bytes 16..17 , shift 1 bits.
	lsrf l_framBuf1+.16,0
	movwf l_Al
	rrf l_framBuf1+.17,0
	movwf l_Ah
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #12, bytes 17..18 , shift 4 bits.
	lsrf l_framBuf1+.17,0
	movwf l_Al
	rrf l_framBuf1+.18,0
	movwf l_Ah
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #13, bytes 18..20 , shift 7 bits.
	lslf l_framBuf1+.18,0
	rlf l_framBuf1+.19,0
	movwf l_Al
	rlf l_framBuf1+.20,0
	movwf l_Ah
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #14, bytes 20..21 , shift 2 bits.
	lsrf l_framBuf1+.20,0
	movwf l_Al
	rrf l_framBuf1+.21,0
	movwf l_Ah
	lsrf l_Ah,1
	rrf l_Al,1
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++
	;channel #15, bytes 21..22 , shift 5 bits.
	lsrf l_framBuf1+.21,0
	movwf l_Al
	rrf l_framBuf1+.22,0
	movwf l_Ah
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	andlw 0x07
	movwi FSR1++

	; channel #16
	movlw low SBUS_VAL_D_LOW
	btfsc l_framBuf1+.23,0
	movlw low SBUS_VAL_D_HIGH
	movwi FSR1++
	movlw high SBUS_VAL_D_LOW
	btfsc l_framBuf1+.23,0
	movlw high SBUS_VAL_D_HIGH
	movwi FSR1++
	; channel #17
	movlw low SBUS_VAL_D_LOW
	btfsc l_framBuf1+.23,1
	movlw low SBUS_VAL_D_HIGH
	movwi FSR1++
	movlw high SBUS_VAL_D_LOW
	btfsc l_framBuf1+.23,1
	movlw high SBUS_VAL_D_HIGH
	movwi FSR1++

	; framelost
	btfsc l_framBuf1+.23,2
	bra $+3
	incfsz l_lastFrameBad,0
	incf l_lastFrameBad,1

	; 'fail-safe'
	clrf WREG
	btfsc l_framBuf1+.23,3
	incf WREG,0
	movwf l_signalLost

	retlw 1

encodeSbusFrame:
	; FSR1 points to data to encode
	; output placed in 25-byte buffer at l_framBuf2
	banksel 0
	movlw 0x0F
	movwf l_framBuf2
	clrf l_framBuf2+.23

	movlw 0x10
	addwf l_lopSBfram,1
	movf l_lopSBfram,0
	andlw 0x30
	addlw 0x04
	clrf WREG
	movwf l_framBuf2+.24

	;channel #0, bytes 1..2 , shift 0 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	movf l_Al,0
	movwf l_framBuf2+.1
	movf l_Ah,0
	movwf l_framBuf2+.2
	;channel #1, bytes 2..3 , shift 3 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,0
	iorwf l_framBuf2+.2,1
	rlf l_Ah,0
	movwf l_framBuf2+.3
	;channel #2, bytes 3..5 , shift 6 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	clrf ml_temp
	lsrf l_Ah,1
	rrf l_Al,1
	rrf ml_temp,1
	lsrf l_Ah,0
	movwf l_framBuf2+.5
	rrf l_Al,0
	movwf l_framBuf2+.4
	rrf ml_temp,0
	iorwf l_framBuf2+.3,1
	;channel #3, bytes 5..6 , shift 1 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	lslf l_Al,0
	iorwf l_framBuf2+.5,1
	rlf l_Ah,0
	movwf l_framBuf2+.6
	;channel #4, bytes 6..7 , shift 4 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,0
	iorwf l_framBuf2+.6,1
	rlf l_Ah,0
	movwf l_framBuf2+.7
	;channel #5, bytes 7..9 , shift 7 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	lsrf l_Ah,0
	movwf l_framBuf2+.9
	rrf l_Al,0
	movwf l_framBuf2+.8
	btfsc STATUS,C
	bsf l_framBuf2+.7,7
	;channel #6, bytes 9..10 , shift 2 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,0
	iorwf l_framBuf2+.9,1
	rlf l_Ah,0
	movwf l_framBuf2+.10
	;channel #7, bytes 10..11 , shift 5 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,0
	iorwf l_framBuf2+.10,1
	rlf l_Ah,0
	movwf l_framBuf2+.11
	;channel #8, bytes 12..13 , shift 0 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	movf l_Al,0
	movwf l_framBuf2+.12
	movf l_Ah,0
	movwf l_framBuf2+.13
	;channel #9, bytes 13..14 , shift 3 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,0
	iorwf l_framBuf2+.13,1
	rlf l_Ah,0
	movwf l_framBuf2+.14
	;channel #10, bytes 14..16 , shift 6 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	clrf ml_temp
	lsrf l_Ah,1
	rrf l_Al,1
	rrf ml_temp,1
	lsrf l_Ah,0
	movwf l_framBuf2+.16
	rrf l_Al,0
	movwf l_framBuf2+.15
	rrf ml_temp,0
	iorwf l_framBuf2+.14,1
	;channel #11, bytes 16..17 , shift 1 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	lslf l_Al,0
	iorwf l_framBuf2+.16,1
	rlf l_Ah,0
	movwf l_framBuf2+.17
	;channel #12, bytes 17..18 , shift 4 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,0
	iorwf l_framBuf2+.17,1
	rlf l_Ah,0
	movwf l_framBuf2+.18
	;channel #13, bytes 18..20 , shift 7 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	lsrf l_Ah,0
	movwf l_framBuf2+.20
	rrf l_Al,0
	movwf l_framBuf2+.19
	btfsc STATUS,C
	bsf l_framBuf2+.18,7
	;channel #14, bytes 20..21 , shift 2 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,0
	iorwf l_framBuf2+.20,1
	rlf l_Ah,0
	movwf l_framBuf2+.21
	;channel #15, bytes 21..22 , shift 5 bits.
	moviw FSR1++
	movwf l_Al
	moviw FSR1++
	andlw 0x07
	movwf l_Ah
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,1
	rlf l_Ah,1
	lslf l_Al,0
	iorwf l_framBuf2+.21,1
	rlf l_Ah,0
	movwf l_framBuf2+.22

	; channel #16
	moviw FSR1++
	moviw FSR1++
	btfsc WREG,2
	bsf l_framBuf2+.23,0
	; channel #17
	moviw FSR1++
	moviw FSR1++
	btfsc WREG,2
	bsf l_framBuf2+.23,1

	; framelost
	movf l_lastFrameBad,0
	btfss STATUS,Z
	bsf l_framBuf2+.23,2

	; 'fail-safe'
	movf l_signalLost,0
	btfss STATUS,Z
	bsf l_framBuf2+.23,3

	return
