#include "p16F1847.inc"


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

ml_lowPass0      = 0x75
ml_lowPass1      = 0x76

ml_rndReg0   = 0x77
ml_rndReg1   = 0x78
ml_rndReg2   = 0x79

ml_poly0     = 0x7A
ml_poly1     = 0x7B
ml_poly2     = 0x7C

l_Al        = 0x20
l_Ah        = 0x21



l_secondsL   = 0x22
l_secondsH   = 0x23


portA_polySel1 = 0
portA_polySel0 = 1
portA_outpin   = 4
portA_polySel3 = 6
portA_polySel2 = 7
portB_led      = 0
portB_RX       = 2
portB_syncIn   = 3
portB_TX       = 5


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
	movlw 0xFF		; no outputs. outpin is set in loop
	movwf TRISA
	movlw 0xFF-(1<<portB_TX)
	movwf TRISB
	banksel OPTION_REG
	bcf OPTION_REG,7	; enable pull-ups with WPUx
	banksel 0


	; UART setup (no interrupts!)
	banksel APFCON0
	bsf APFCON1,0		; TXCKSEL: move UART TX to B5
	bsf APFCON0,7		; RXDTSEL: move UART RX to B2

	; UART BAUD rate setup.
	; formula for baudrate value:
	;  32e6/(4*115200)-1
	banksel BAUDCON
	movlw 0x48
	movwf BAUDCON		; RCIDL (BRG16=1)
	banksel TXSTA
	bcf TXSTA,4	; SYNC
	bsf TXSTA,2 ; BRGH
	; Set to 115.2 kBaud.
	banksel SPBRGL
	movlw 0x44
	movwf SPBRGL
	movlw 0x00
	movwf SPBRGH

	; UART TX
	banksel TXSTA
	bsf TXSTA,5	; TXEN (go)
	banksel RCSTA
	bsf RCSTA,7	; SPEN

	; UART RX setup.
	banksel RCSTA
	bcf RCSTA,6 ; RX9
	bsf RCSTA,4 ; CREN (go!)
	banksel PIE1
	bcf PIE1,5	; without intrr


	; timer 2 is clock for PWM register.
	; speed is 200000 pulses per second, or 40 inst-cycles per sample.
	banksel TMR2
	movlw 0x1F	; 32
	movwf PR2
	movlw 0x00	; no pre/postscale, not yet enable.
	movwf T2CON
	banksel PIE1
	bcf PIE1,1  ; TMR2IE  disable int


	; prepare PWM register, using CCP4
	banksel CCPTMRS	; select timer2 for CCP4
	bcf CCPTMRS,6
	bcf CCPTMRS,7
	banksel CCP4CON
	movlw 0x0C		; select PWM mode
	movwf CCP4CON
	movlw 0x10	; preload 50%
	movwf CCPR4L



	; timer4 is the time-clock. always running without ints.  64*10*250=160000 -> 50 Hz (@8MHz).
	; value is polled from mainloop. It wraps slow enough for this.
	; timer 4 period is 160000 cycles.
	banksel TMR4
	movlw 0xF9	; 250-1
	movwf PR4
	movlw 0x4F  ; prescale=64, enable, postscale=1:10
	movwf T4CON
	clrf ml_timeCount
	banksel PIE3
	bcf PIE3,1  ; disable int


	clrf ml_timeCount
	clrf l_secondsL
	clrf l_secondsH

	clrf ml_lowPass0
	clrf ml_lowPass1
	movlw 0xFF
	movwf ml_lowPass0
	movlw 0x7F
	movwf ml_lowPass1

	; poly 8146F2  ( is reversed, low-bit (highest power term) shifted off )
	movlw 0x81
	movwf ml_poly2
	movlw 0x46
	movwf ml_poly1
	movlw 0xF2
	movwf ml_poly0



mainloop:
	; wait for timer4 
	banksel PIR3
	btfss PIR3,1		; TMR4IF
	bra $-1
	bcf PIR3,1		; TMR4IF
	banksel 0
	; here, we are in sync with timer4, with a jitter of +/- 1 (3 possibilities)
	; an error of 3 inst-clocks is a sound-travel distance of 0.13mm


	; start PWM
	bcf PIR1,1		; TMR2IF
	banksel TMR2
	movlw 0x1E
	movwf TMR2
	movlw 0x04
	movwf T2CON	; start timer
	; wait for one loop
	btfss PIR1,1		; TMR2IF
	bra $-1
	; enable output pin
	banksel TRISA
	bcf TRISA,portA_outpin
	bcf TRISB,portB_led
	banksel 0

	; send 'P'
	banksel TXREG
	movlw 'P'
	movwf TXREG


	; load number of cycles in ml_temp./2
	; 50000 loops is 200msec.
	movlw low .49999
	movwf ml_temp
	movlw high .49999
	movwf ml_temp2


	; reset random-register
	movlw 0xFF
	movwf ml_rndReg0
	movwf ml_rndReg1
	movwf ml_rndReg2
	; reset lospass-register
	movlw 0xFF
	movwf ml_lowPass0
	movlw 0x1F
	movwf ml_lowPass1

	; wait for timer2.
	banksel 0
	btfss PIR1,1		; TMR2IF
	bra $-1
	banksel CCP4CON	; stay in bank of CCP4 all the loop
	bra loop_noXORpolyB

loop_noXORpolyA:
	nop
	nop
	nop
	bra loop_noXORpolyB

	; loop (32 cycles per loop)
soundLoopp2:
	nop
	nop
soundLoop:
	; run random-poly
	lsrf ml_rndReg2,1
	rrf ml_rndReg1,1
	rrf ml_rndReg0,1
	btfss STATUS,C
	bra loop_noXORpolyA	; indirect jump to loop_noXORpolyB, staying in sync.
	movf ml_poly2,0
	xorwf ml_rndReg2,1
	movf ml_poly1,0
	xorwf ml_rndReg1,1
	movf ml_poly0,0
	xorwf ml_rndReg0,1
loop_noXORpolyB:
	movf ml_rndReg0,0
	addwf ml_lowPass0,1
	movf ml_rndReg1,0
	andlw 0x3F
	addwfc ml_lowPass1,1
	rrf ml_lowPass1,1
	rrf ml_lowPass0,1
	; time up to here:   18 cycles
	lsrf ml_lowPass1,0
	movwf CCPR4L
	; 20
	bcf CCP4CON,4
	bcf CCP4CON,5
	btfsc ml_lowPass0,7
	bsf CCP4CON,4
	btfsc ml_lowPass1,0
	bsf CCP4CON,5
	; 26
	nop
	; 27
	decfsz ml_temp,1
	bra soundLoopp2
	decfsz ml_temp2,1
	bra soundLoop

	; stop PWM, disable output pin
	banksel TRISA
	bsf TRISA,portA_outpin
	bsf TRISB,portB_led
	banksel CCP4CON
	movlw 0x10	; load 50%
	movwf CCPR4L
	banksel T2CON
	bcf T2CON,2
	banksel 0
	; up to here, we had roughly 50000*32 = 1.6M instructions.


	movlw 0x0A
	addwf ml_timeCount,1
	movlw 0x32	; 50
	subwf ml_timeCount,0
	btfsc STATUS,C
	clrf ml_timeCount



	banksel 0

	bcf PIR3,1		; TMR4IF
	btfss PIR3,1
	bra $-1
	bcf PIR3,1		; TMR4IF
	btfss PIR3,1
	bra $-1
	bcf PIR3,1		; TMR4IF
	btfss PIR3,1
	bra $-1
	bcf PIR3,1		; TMR4IF


	bra mainloop




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


;	org 0x1000


	end



