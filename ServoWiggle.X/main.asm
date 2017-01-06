#include "p12F1840.inc"


;config bits: internal osc.
; CONFIG1
; __config 0x2F84
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_ON & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_ON
; CONFIG2
; __config 0x1FFF
 __CONFIG _CONFIG2, _WRT_OFF & _PLLEN_ON & _STVREN_ON & _BORV_LO & _LVP_OFF


; vars on all banks
ml_temp          = 0x70		; used by any subrt.
ml_temp2         = 0x71		; used by any subrt.
ml_temp3         = 0x72		; used by 'bigger' subrt.
ml_temp4         = 0x73		; used by 'bigger' subrt.
ml_timeCount     = 0x74		; advances 50/sec
ml_seconds       = 0x75

ml_servoPosL    = 0x76	; 0 ... 8000
ml_servoPosH    = 0x77

l_Al        = 0x20
l_Ah        = 0x21

l_secondsL   = 0x22
l_secondsH   = 0x23

ml_servodir   = 0x7E
ml_servopos   = 0x7F


portA_servo = 4
portA_led = 5


	org 0
	goto skipToSetup

	org 4
	retfie

skipToSetup:
	; oscillator setup ..... To get 32MHz internal, FOSC=100 (INTOSC), SCS=00 (source=INTOSC), IRCF=1110 (8MHz), SPLLEN=1 (PLLEN)
	movlw 0xF0	; PLL on, int osc 8MHz, clockselect by config.
	banksel OSCCON
	movwf OSCCON
	banksel 0

	movlw low 500-4
	movwf l_Al
	movlw high 500-4
	movwf l_Ah
	call delay_Alh


;	movlw 0xC8
;pauseOsc:
;	nop
;	nop
;	decfsz WREG,0
;	bra pauseOsc

	; port setup
	banksel ANSELA
	clrf ANSELA
	banksel WPUA
	movlw 0xFF
	movwf WPUA
	banksel LATA
	bcf LATA,portA_servo
	bcf LATA,portA_led
	banksel TRISA
	movlw 0xFF-(1<<portA_servo)
	movwf TRISA
	banksel OPTION_REG
	bcf OPTION_REG,7	; enable pull-ups with WPUx
	banksel 0


	; timer2 is the time-clock. always running without ints.  64*10*250=160000 -> 50 Hz (@8MHz).
	; value is polled from mainloop. It wraps slow enough for this.
	; timer 2 period is 160000 cycles.
	banksel TMR2
	movlw 0xF9	; 250-1
	movwf PR2
	movlw 0x4F  ; prescale=64, enable, postscale=1:10
	movwf T2CON
	clrf ml_timeCount
	banksel PIE1
	bcf PIE1,1  ; disable int


	clrf ml_timeCount
	clrf l_secondsL
	clrf l_secondsH
	clrf ml_servodir
	movlw 0x80
	movwf ml_servopos
	movlw low .4000
	movwf ml_servoPosL
	movlw high .4000
	movwf ml_servoPosH

mainloop:
	; wait timer
	banksel 0
	btfss PIR1,1
	bra $-1
	bcf PIR1,1
	incf ml_timeCount,1
	movlw 0x32	; 50
	subwf ml_timeCount,0
	btfss STATUS,C
	bra noSecondTick
	clrf ml_timeCount
	incf l_secondsH,1
noSecondTick:
	; calc 5.125*timecount
	lslf ml_timeCount,0
	lslf WREG,0
	addwf ml_timeCount,0
	movwf l_secondsL
	lsrf ml_timeCount,0
	lsrf WREG,0
	lsrf WREG,0
	addwf l_secondsL,1



	banksel 0
;	movlw low .4000
;	movwf ml_servoPosL
;	movlw high .4000
;	movwf ml_servoPosH

	; 1ms is 8000 cycles.

	banksel LATA
	bsf LATA,portA_servo
	banksel 0


	movlw low .7992
	addwf ml_servoPosL,0
	movwf l_Al
	movlw high .7992
	addwfc ml_servoPosH,0
	movwf l_Ah
	call delay_Alh

	banksel LATA
	bcf LATA,portA_servo
	banksel 0


	; alive-LED
	; divide-modulo by 50
	movf ml_timeCount,0
	movwf ml_temp
	movlw 0x32
	subwf ml_temp,0
	btfss STATUS,C
	bra $+3
	movwf ml_temp
	bra $-5
	; have modulo.
	banksel TRISA
	movlw 0x19
	subwf ml_temp,0
	btfss STATUS,C
	bra $+4
	nop
	bcf TRISA,portA_led
	bra $+2
	bsf TRISA,portA_led

	banksel 0

	; reposition
	movlw high getSine8bitSigned_256circle
	movwf PCLATH
	lsrf l_secondsH,0
	movwf ml_temp
	rrf l_secondsL,0
	lsrf ml_temp,1
	rrf WREG,0

	movf l_secondsL,0

	call getSine8bitSigned_256circle

	movwf ml_servoPosL
	clrf ml_servoPosH
	btfsc WREG,7
	decf ml_servoPosH,1

	lslf ml_servoPosL,1
	rlf ml_servoPosH,1
	lslf ml_servoPosL,1
	rlf ml_servoPosH,1
	lslf ml_servoPosL,1
	rlf ml_servoPosH,1
	lslf ml_servoPosL,1
	rlf ml_servoPosH,1
	lslf ml_servoPosL,1
	rlf ml_servoPosH,1

	movlw low .4000
	addwf ml_servoPosL,1
	movlw high .4000
	addwfc ml_servoPosH,1
;	movf l_secondsH,0
;	addwf ml_servoPosH,1

	movlw 0
	movwf PCLATH




	bra mainloop



posArray:
	andlw 3
	brw
	bra pos0
	bra pos1
	bra pos2
	bra pos3

pos0:
	movlw low .0
	movwf ml_servoPosL
	movlw high .0
	movwf ml_servoPosH
	return
pos1:
	movlw low .4000
	movwf ml_servoPosL
	movlw high .4000
	movwf ml_servoPosH
	return
pos2:
	movlw low .4000
	movwf ml_servoPosL
	movlw high .4000
	movwf ml_servoPosH
	return
pos3:
	movlw low .8000
	movwf ml_servoPosL
	movlw high .8000
	movwf ml_servoPosH
	return


delay_Alh:
	; delay variable amount, value in l_Al,l_Ah.
	; includes time for call and return.
	; does not include setup-time for l_Al/l_Ah.
	; minimum is 13 cycles.
	; if request is too short, returns number of cycles over.
	movlw 0xE0
	andwf l_Al,0
	iorwf l_Ah,0
	btfss STATUS,Z
	bra delay_Alh_high
	; wenn reaching this point, we already used 7 not counted (incl 2 for call-in)
	movf l_Al,0
	xorlw 0x1F
	brw		; with brw and return, have a total of 7+2+2+2=14 not counted.

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	; a l_Al of 16 would hop here. need 3 nops then

	nop
	nop
	retlw 0x00
	retlw 0x01
	retlw 0x02
	retlw 0x03
	retlw 0x04
	retlw 0x05

	retlw 0x06
	retlw 0x07
	retlw 0x08
	retlw 0x09
	retlw 0x0A
	retlw 0x0B
	retlw 0x0C
	retlw 0x0D

	retlw 0x7F
delay_Alh_high:
	movlw 0x0C
	subwf l_Al,1
	movlw 0
	subwfb l_Ah,1
	bra delay_Alh


	org 0x0800

#include "mathTables.asm"



	end


