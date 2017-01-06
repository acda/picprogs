

haveRX:
	; Check if have any data in RX ringbuffer, without picking up. Returns number of bytes.
	; max 9
	banksel 0
	movf l_bufRXout,0
	subwf l_bufRXin,0
	btfss STATUS,C
	addlw bufferRXend-bufferRX
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


getRX:
	; get a byte from RX ringbuffer (or 0xFF if none). ml_temp==1 indicates if valid.
	; max 27
	banksel 0
	clrf ml_temp
	movf l_bufRXout,0
	subwf l_bufRXin,0
	btfsc STATUS,Z
	retlw 0xFF
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
	clrf ml_temp
	incf ml_temp,1
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
	moviw FSR0++
	banksel TXREG
	movwf TXREG
	banksel 0
	incf l_bufTXout,1
	movlw bufferTXend-bufferTX
	subwf l_bufTXout,0
	btfsc STATUS,C
	clrf l_bufTXout
	retlw 1

testRX:
	; Check if there is a byte to transfer from RX hardware to ringbuffer
	; max 23
	banksel 0
	btfss PIR1,5	; RCIF
	retlw 0
	movlw high bufferRX
	movwf FSR0H
	movlw low bufferRX
	addwf l_bufRXin,0
	movwf FSR0L
	btfsc STATUS,C
	incf FSR0H,1
	banksel RCREG
	movf RCREG,0
	banksel 0
	movwi FSR0++
	incf l_bufRXin,1
	movlw bufferRXend-bufferRX
	subwf l_bufRXin,0
	btfsc STATUS,C
	clrf l_bufRXin
	retlw 1


