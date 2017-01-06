

;haveRXS:
;	; Check if have any data in RXS ringbuffer, without picking up. Returns number of bytes.
;	; max 9
;	banksel 0
;	movf ml_bufRXSout,0
;	subwf ml_bufRXSin,0
;	btfss STATUS,C
;	addlw bufferRXSend-bufferRXS
;	return
;

haveTXS:
	; Check if have any data in TXS. Returns number of bytes.
	; max 9
	banksel 0
	movf ml_bufTXSout,0
	subwf ml_bufTXSin,0
	btfss STATUS,C
	addlw bufferTXSend-bufferTXS
	return


;getRXS:
;	; get a byte from RXS ringbuffer (or 0xFF if none). ml_temp==1 indicates if valid.
;	; max 27
;	banksel 0
;	clrf ml_temp
;	movf ml_bufRXSout,0
;	subwf ml_bufRXSin,0
;	btfsc STATUS,Z
;	retlw 0xFF
;	movlw high bufferRXS
;	movwf FSR0H
;	movlw low bufferRXS
;	addwf ml_bufRXSout,0
;	movwf FSR0L
;	btfsc STATUS,C
;	incf FSR0H,1
;	moviw FSR0++
;	movwf ml_temp
;	incf ml_bufRXSout,1
;	movlw bufferRXSend-bufferRXS
;	subwf ml_bufRXSout,0
;	btfsc STATUS,C
;	clrf ml_bufRXSout
;	movf ml_temp,0
;	clrf ml_temp
;	incf ml_temp,1
;	return
;

putTXS:
	; put a byte into the TXS ringbuffer
	; max 45
	banksel 0
	movwf ml_temp
	movlw high bufferTXS
	movwf FSR0H
	movlw low bufferTXS
	addwf ml_bufTXSin,0
	movwf FSR0L
	btfsc STATUS,C
	incf FSR0H,1
	movf ml_temp,0
	movwi FSR0++
	movlw (bufferTXSend-bufferTXS)-1
	subwf ml_bufTXSin,0
	btfsc STATUS,C
	bra $+3
	incf ml_bufTXSin,1
	bra $+2
	clrf ml_bufTXSin
	; fall through to testTX function

testTXS:
	return

;testRXS:
;	return
;




