

sendLEDstrip:
	movlw NUM_LEDS
	movwf ml_count
	movlw low bufferLED
	movwf FSR0L
	movlw high bufferLED
	movwf FSR0H

LEDloop:
	; get green value from buffer
	banksel 0
	moviw FSR0++
	movwf ml_temp ; first ist red, buffer it.
	moviw FSR0++ ; green
	banksel LATA
	clrf ml_bitcount
;	    lsrf WREG,0
loopG:
	bsf LATA,portA_pin		; clk
	nop
	btfss WREG,7
	bcf LATA,portA_pin
	lslf WREG,1
	bcf LATA,portA_pin
	incf ml_bitcount,1
	btfss ml_bitcount,3
	bra loopG

	; timer tick
	banksel 0
	btfss PIR1,1		; TMR2IF
	bra $+3
	bcf PIR1,1		; TMR2IF
	incf ml_timeCount,1

	; get R-value
	movf ml_temp,0
	banksel LATA
	clrf ml_bitcount
;	    lsrf WREG,0
loopR:
	bsf LATA,portA_pin		; clk +15 or +17
	nop
	btfss WREG,7
	bcf LATA,portA_pin
	lslf WREG,1
	bcf LATA,portA_pin
	incf ml_bitcount,1
	btfss ml_bitcount,3
	bra loopR

	banksel 0
	; get B-value
	moviw FSR0++
	banksel LATA
	clrf ml_bitcount
;	    lsrf WREG,0
loopB:
	bsf LATA,portA_pin		; clk +13 or +15
	nop
	btfss WREG,7
	bcf LATA,portA_pin
	lslf WREG,1
	bcf LATA,portA_pin
	incf ml_bitcount,1
	btfss ml_bitcount,3
	bra loopB
	; done
	; loop
	banksel 0
	decfsz ml_count,1
	bra LEDloop


;	banksel LATA
;	bsf LATA,portA_pin
;	nop
;	nop
;	bcf LATA,portA_pin

	banksel 0

	movlw #2
	movwf ml_temp
	nop
	decfsz WREG,0
	bra $-2
	decfsz ml_temp,1
	bra $-4


	return


;#!/usr/bin/python
;import math
;vals=list();gamma=1.95;num=64
;for i in xrange(num):
; vals.append( max( int(255.0*math.pow(i/float(num-1),gamma)+0.5) , i ) )
;
;for i in xrange(0,num,16):
; print 'dw '+','.join("0x34%02X"%b for b in vals[i:i+16])
gamma5:
	; max 7
	andlw 0x1F
	brw
	dw 0x3400,0x3401,0x3402,0x3403,0x3405,0x3407,0x340A,0x340E,0x3412,0x3417,0x341C,0x3422,0x3428,0x342F,0x3436,0x343E
	dw 0x3446,0x344F,0x3458,0x3462,0x346C,0x3477,0x3483,0x348E,0x349B,0x34A8,0x34B5,0x34C3,0x34D1,0x34E0,0x34EF,0x34FF

gamma6:
	; max 7
	andlw 0x3F
	brw
	dw 0x3400,0x3401,0x3402,0x3403,0x3404,0x3405,0x3406,0x3407,0x3408,0x3409,0x340A,0x340B,0x340C,0x340D,0x340E,0x3410
	dw 0x3412,0x3414,0x3416,0x3419,0x341B,0x341E,0x3421,0x3424,0x3427,0x342A,0x342D,0x3431,0x3434,0x3438,0x343C,0x3440
	dw 0x3444,0x3448,0x344D,0x3451,0x3456,0x345A,0x345F,0x3464,0x3469,0x346E,0x3474,0x3479,0x347F,0x3484,0x348A,0x3490
	dw 0x3496,0x349C,0x34A2,0x34A9,0x34AF,0x34B6,0x34BD,0x34C4,0x34CB,0x34D2,0x34D9,0x34E0,0x34E8,0x34EF,0x34F7,0x34FF
	retlw 0xFF



