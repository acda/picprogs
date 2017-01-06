

; Do query on I2C bus. Read register 5.
; result in ml_temp/ml_temp2  (low/high)

I2C_IO:
	; first, send device-Address
	andlw 0x07
	movwf ml_temp2
	banksel SSP1CON2
	bsf SSP1CON2,0		; SEN
	call waitI2C
	banksel SSP1BUF
	lslf ml_temp2,0
	iorlw 0x30+0
	movwf SSP1BUF
	call waitI2C_testRXTX
	; have ack?
	banksel SSP1CON2
	btfsc SSP1CON2,6	; ACKSTAT
	retlw 0xFF		; no ack. bad device ID or other fault.
	banksel SSP1BUF
	movlw 0x05		; select register 5 in MCP9808 device
	movwf SSP1BUF
	call waitI2C_testRXTX
	banksel SSP1CON2
	bsf SSP1CON2,2	; do stop
	call waitI2C
	; have stopped. Now start for read.
	; first, send device-Address
	banksel SSP1CON2
	bsf SSP1CON2,0		; SEN
	call waitI2C
	banksel SSP1BUF
	lslf ml_temp2,0
	iorlw 0x30+1	; +1 to do a read.
	movwf SSP1BUF
	call waitI2C_testRXTX
	; have ack?
	banksel SSP1CON2
	btfsc SSP1CON2,6	; ACKSTAT
	retlw 0xFE		; no ack. bad device ID or other fault.
	; read two bytes
	banksel SSP1CON2
	bsf SSP1CON2,3		; RCEN
	call waitI2C_testRXTX
	banksel SSP1BUF
	movf SSP1BUF,0		; pick up highbyte
	movwf ml_temp2
	banksel SSP1CON2
	bcf SSP1CON2,5		; ACKDT
	bsf SSP1CON2,4		; ACKEN
	call waitI2C
	banksel SSP1CON2
	bsf SSP1CON2,3		; RCEN
	call waitI2C_testRXTX
	banksel SSP1BUF
	movf SSP1BUF,0		; pick up lowbyte
	movwf ml_temp3
	banksel SSP1CON2
	bsf SSP1CON2,5		; ACKDT
	bsf SSP1CON2,4		; ACKEN
	call waitI2C
	banksel SSP1CON2
	bsf SSP1CON2,2		; PEN
	call waitI2C

	call testTX
	call testRX

	; move and sign-extend
	movlw 0x1F
	andwf ml_temp2,1
	movlw 0xE0
	btfsc ml_temp2,4
	iorwf ml_temp2,1
	movf ml_temp3,0
	movwf ml_temp

	retlw 0

waitI2C:
	banksel SSP1STAT
	movf SSP1CON2,0
	andlw 0x1F
	btfss STATUS,Z
	bra waitI2C
	movf SSP1STAT,0
	andlw 0x04
	btfss STATUS,Z
	bra waitI2C
	return

waitI2C_testRXTX:
	call testTX
	call testRX
	banksel SSP1STAT
	movf SSP1CON2,0
	andlw 0x1F
	btfss STATUS,Z
	bra waitI2C_testRXTX
	movf SSP1STAT,0
	andlw 0x04
	btfss STATUS,Z
	bra waitI2C_testRXTX
	return

