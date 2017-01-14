
; uart buffer functions
; testRX does not test for buffer overrun
; putTX will drop if full and return 0.
; buffersize max 255 bytes (one-byte in and out indices)


haveRX:
	; Check if have any data in RX ringbuffer, without picking up. Returns number of bytes.
	; max 9
	banksel 0
	movf l_bufRXin,0
	return

haveTX:
	; Check if have any data in TX. Returns number of bytes.
	; max 9
	banksel 0
	movf l_bufTXout,0
	subwf l_bufTXin,0
	btfss STATUS,C
	addlw bufferTXend-bufferTX
	return



putTX:
	; put a byte into the TX ringbuffer
	; max 45
	banksel 0
	movwf ml_temp
	movlw high bufferTX
	movwf FSR0H
	movlw low bufferTX
	addwf l_bufTXin,0
	movwf FSR0L
	btfsc STATUS,C
	incf FSR0H,1
	movf ml_temp,0
	movwi FSR0++
	incf l_bufTXin,1
	movlw bufferTXend-bufferTX
	subwf l_bufTXin,0
	btfsc STATUS,C
	clrf l_bufTXin
	; fall through to textTX function

testTX:
	; Check if there is a byte to transfer from ringbuffer to TX hardware
	; max 27
	banksel 0
	btfss PIR1,4	; TXIF
	retlw 0
	movf l_bufTXout,0
	subwf l_bufTXin,0
	btfsc STATUS,Z
	retlw 0
	movlw high bufferTX
	movwf FSR0H
	movlw low bufferTX
	addwf l_bufTXout,0
	movwf FSR0L
	btfsc STATUS,C
	incf FSR0H,1
	banksel TXREG
	moviw 0[FSR0]
	movwf TXREG
	banksel 0
	incf l_bufTXout,1
	movlw bufferTXend-bufferTX
	subwf l_bufTXout,0
	btfsc STATUS,C
	clrf l_bufTXout
	retlw 1

testRX:
testRX__exectime = .23
	; Check if there is a byte to transfer from RX hardware to ringbuffer
	; max 2+21
	; input: If W!=0, return quickly if no data available.
	;        if W==0, do wait so execution time is always exactly same.
	banksel 0
	btfss PIR1,5	; RCIF
	bra testRX_resttime
	movlw high bufferRX
	movwf FSR0H
	movlw low bufferRX
	addwf l_bufRXin,0
	movwf FSR0L
	btfsc STATUS,C
	incf FSR0H,1
	banksel RCREG
	movf RCREG,0
	movwi 0[FSR0]
	banksel 0
	; inc in, reset if reach end.
	incf l_bufRXin,1
	movlw bufferRXend-bufferRX
	subwf l_bufRXin,0
	btfsc STATUS,C
	clrf l_bufRXin
	retlw 1
testRX_resttime:
	; no data. waste remaining time?
	movf WREG,0
	btfss STATUS,Z
	retlw 0	; do not adjust.
	; waste time to make execution time constant.
	; here, have already used 2+7 clocks (2 for call-in) two for retlw. waste 21-9 clocks
	movlw (.21-.9)/3 ; works if value is divisable by three. otherwise add nops.
	decfsz WREG,1
	bra $-1
	retlw 0


testRXavail:
	; returns 0 if empty, non-0 otherwise.
	movf l_bufRXin,0
	xorwf l_bufRXout,0
	return

testRX_OERR:
	banksel RCSTA
	btfsc RCSTA,OERR
	bra $+3
	banksel 0
	return
	; is oerr. disable/enable RX. drop all data.
	bcf RCSTA,CREN
	banksel 0
	movf l_bufRXin,0
	movwf l_bufRXout
	banksel RCSTA
	bsf RCSTA,CREN
	banksel 0
	return


getRX:
	; get a byte from the RX ringbuffer (must have checked availability before!)
	; time: 2+18
	banksel 0
	movlw high bufferRX
	movwf FSR0H
	movlw low bufferRX
	addwf l_bufRXout,0
	movwf FSR0L
	btfsc STATUS,C
	incf FSR0H,1
	moviw FSR0++
	movwf ml_temp
	incf l_bufRXout,1
	movlw bufferRXend-bufferRX
	subwf l_bufRXout,0
	btfsc STATUS,C
	clrf l_bufRXout
	movf ml_temp,0
	return

getRX_many:
	; get bytes available, place in [FSSR1++]
	; at most W bytes.
	; returns bytes retrieved.
	; uses temp and temp2
	banksel 0
	movwf ml_temp2
	movlw high bufferRX
	movwf FSR0H
	movlw low bufferRX
	addwf l_bufRXout,0
	movwf FSR0L
	btfsc STATUS,C
	incf FSR0H,1
	movf l_bufRXout,0
	subwf l_bufRXin,0
	btfsc STATUS,C
	bra $+3  ; data not wrapped
	; data is wrapped
	movf l_bufRXout,0
	sublw bufferRXend-bufferRX
	movwf ml_temp
	; limit against value passed in
	movf ml_temp2,0
	subwf ml_temp,0
	movf ml_temp2,0
	btfss STATUS,C ; skip if limit or beyond
	movf ml_temp,0
	; loop-copy
	movwf ml_temp
	movwf ml_temp2
	btfsc STATUS,Z
	bra $+5
	moviw FSR0++
	movwi FSR1++
	decfsz ml_temp2,1
	bra $-3
	movf ml_temp,0
	; increment the out ptr.
	addwf l_bufRXout,1
	movlw bufferRXend-bufferRX
	subwf l_bufRXout,0
	btfsc STATUS,C
	movwf l_bufRXout
	movf ml_temp,0
	return

