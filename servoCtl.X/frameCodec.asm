

decodeFrame:
	; FSR1 points to target buffer of decoded data
	; input taken from buffer at l_framBuf
	; takes roughly 440
	banksel 0

	movlw low l_framBuf
	movwf FSR0L
	movlw high l_framBuf
	movwf FSR0H
	moviw 2[FSR0]	; num channels
	btfsc STATUS,Z
	retlw 0	; zero channels??
	movwf ml_temp2
	; sanity check... (max 12)
	movlw .12
	subwf ml_temp2,0
	movlw .12
	btfsc STATUS,C
	movwf ml_temp2
	; set up loop
	addfsr FSR0,3
_lop_decod_fram:
	; servo value. shift left 4 to align to 16-bit
	moviw 1[FSR0]
	movwf ml_temp
	moviw 0[FSR0]
	lslf WREG,0
	rlf ml_temp,1
	lslf WREG,0
	rlf ml_temp,1
	lslf WREG,0
	rlf ml_temp,1
	lslf WREG,0
	rlf ml_temp,1
	movwi FSR1++
	movf ml_temp,0
	movwi FSR1++
	; servo-step value. shift to low-align.
	moviw 2[FSR0]
	movwf ml_temp
	moviw 1[FSR0]
	lsrf ml_temp,1
	rrf WREG,0
	lsrf ml_temp,1
	rrf WREG,0
	lsrf ml_temp,1
	rrf WREG,0
	lsrf ml_temp,1
	rrf WREG,0
	movwi FSR1++
	movf ml_temp,0
	btfsc WREG,3
	iorlw 0xF0
	movwi FSR1++
	; loop
	addfsr FSR0,3
	decfsz ml_temp2,1
	bra _lop_decod_fram

	retlw 1
