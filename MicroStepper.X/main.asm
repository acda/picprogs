#include "p16F1847.inc"


;config bits: internal osc.
; CONFIG1
; __config 0x2F84
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_ON & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_ON
; CONFIG2
; __config 0x1FFF
 __CONFIG _CONFIG2, _WRT_OFF & _PLLEN_ON & _STVREN_ON & _BORV_LO & _LVP_OFF


STEP_TICKS = .4000
LOOPCODE_TICKS = .54



; vars on all banks
ml_temp          = 0x70		; used by any subrt.
ml_temp2         = 0x71		; used by any subrt.
ml_temp3         = 0x72		; used by 'bigger' subrt.
ml_temp4         = 0x73		; used by 'bigger' subrt.
ml_timeCount     = 0x74		; advances 50/sec
ml_seconds       = 0x75

ml_motPos = 0x78

l_Al        = 0x20
l_Ah        = 0x21

l_secondsL   = 0x22
l_secondsH   = 0x23

ml_servodir   = 0x7E
ml_servopos   = 0x7F


portA_mot_x0 = 1
portA_mot_x1 = 0
portA_mot_y0 = 7
portA_mot_y1 = 6
portB_led      = 0


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
	clrf ANSELB
	banksel WPUA
	movlw 0xFF
	movwf WPUA
	movwf WPUB
	banksel LATA
	bcf LATB,portB_led
	banksel TRISA
	movlw 0x3C
	movwf TRISA
	movlw 0xFF
	movwf TRISB
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

	clrf ml_motPos


mainloop:
	banksel 0

	; check timer
	btfss PIR1,1
	bra noTmr
	bcf PIR1,1
	incf ml_timeCount,1
	movlw 0x32	; 50
	subwf ml_timeCount,0
	btfsc STATUS,C
	movwf ml_timeCount
	btfsc STATUS,C
	incf l_secondsH,1
	bra $+0x0A
noTmr:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	; calc 5.125*timecount to get secondsL
	lslf ml_timeCount,0
	lslf WREG,0
	addwf ml_timeCount,0
	movwf l_secondsL
	lsrf ml_timeCount,0
	lsrf WREG,0
	lsrf WREG,0
	addwf l_secondsL,1

	; up to here, mainloop used 21 cycles.


	banksel 0



	; alive-LED (bit #7 of secondsL)
	btfsc l_secondsL,7
	bra $+5
	nop
	banksel TRISB
	bcf TRISB,portB_led
	bra $+5
	banksel TRISB
	bsf TRISB,portB_led
	nop
	nop
	banksel 0
	; up to here, mainloop used 30 cycles.


	movlw low (STEP_TICKS-LOOPCODE_TICKS)
	movwf l_Al
	movlw high (STEP_TICKS-LOOPCODE_TICKS)
	movwf l_Ah
	call delay_Alh


	incf ml_motPos,1
	movf ml_motPos,0
	call mapBits4motor
	movwf ml_temp
	banksel LATA
	movf LATA,0
	andlw 0xFF-(1<<portA_mot_x0)-(1<<portA_mot_x1)-(1<<portA_mot_y0)-(1<<portA_mot_y1)
	iorwf ml_temp,0
	movwf LATA
	banksel 0



	bra mainloop


mapBits4motor:
	; 7 cycles
	lsrf WREG,0
	lsrf WREG,0
	andlw 7
	brw
;	retlw (1<<portA_mot_x0)+(1<<portA_mot_y0)
;	retlw (1<<portA_mot_x0)+(1<<portA_mot_y0)
;	retlw (1<<portA_mot_x0)+(1<<portA_mot_y1)
;	retlw (1<<portA_mot_x0)+(1<<portA_mot_y1)
;	retlw (1<<portA_mot_x1)+(1<<portA_mot_y1)
;	retlw (1<<portA_mot_x1)+(1<<portA_mot_y1)
;	retlw (1<<portA_mot_x1)+(1<<portA_mot_y0)
;	retlw (1<<portA_mot_x1)+(1<<portA_mot_y0)

	retlw                   (1<<portA_mot_y0)
	retlw (1<<portA_mot_x0)+(1<<portA_mot_y0)
	retlw (1<<portA_mot_x0)
	retlw (1<<portA_mot_x0)+(1<<portA_mot_y1)
	retlw                   (1<<portA_mot_y1)
	retlw (1<<portA_mot_x1)+(1<<portA_mot_y1)
	retlw (1<<portA_mot_x1)
	retlw (1<<portA_mot_x1)+(1<<portA_mot_y0)



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



	end


