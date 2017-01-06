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



ml_freqLL   = 0x74
ml_freqL    = 0x75
ml_freqH    = 0x76
ml_angleLL  = 0x77
ml_angleL   = 0x78
ml_angleH   = 0x79
ml_value    = 0x7A
ml_val_Preg = 0x7B
ml_val_Pcon = 0x7C
ml_rndL     = 0x7D
ml_rndH     = 0x7E

l_Al        = 0x20
l_Ah        = 0x21



l_secondsL   = 0x22
l_secondsH   = 0x23


portA_outpin_PWM4 = 4
portA_outpin_PWM3 = 3
portA_outpin_PWM2 = 7
portB_led      = 0
portB_RX       = 2
portB_syncIn   = 3
portB_TX       = 5


RND_POLY_16 = 0xF6EB

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


	; setup timer 0 as simple timer with 1:256 prescale.
	banksel OPTION_REG
	bcf OPTION_REG,3	; PSA  enable timer0 prescaler
	bcf OPTION_REG,5	; TMR0CS  select inst-clock as trigger for timer0
	movlw 7
	iorwf OPTION_REG,1	; PS:=7 -> timer0 prescaler 1:256
	banksel CPSCON0
	bcf CPSCON0,0	; T0XCS  T0clk by timer0 module or inst-clock.
	; set timer1 to count timer-0 loops.
	banksel T1CON
	movlw 0x81		; gated, timer-0 source.
	movwf T1GCON
	clrf TMR1L
	clrf TMR1H
	movlw 0x01		; inst-clk, 1:1 pre, no ded osc., enable
	movwf T1CON


	banksel 0


	; UART setup (no interrupts!)
	banksel APFCON0
	bsf APFCON1,0		; TXCKSEL: move UART TX to B5
	bsf APFCON0,7		; RXDTSEL: move UART RX to B2
	bsf APFCON0,3		; CCP2SEL: move PWM2 to A7


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
;	banksel RCSTA
;	bcf RCSTA,6 ; RX9
;	bsf RCSTA,4 ; CREN (go!)
;	banksel PIE1
;	bcf PIE1,5	; without intrr


	; timers 2,4,6 for the three PWMs. clocks are 32 inst-cycles, or 250kHz
	; timer 2
	banksel TMR2
	movlw 0x1F	; loop 32
	movwf PR2
	movlw 0x00	; no pre/postscale, not yet enable.
	movwf T2CON
	banksel PIE1
	bcf PIE1,1  ; TMR2IE  disable int
	banksel TMR4
	movlw 0x1F	; loop 32
	movwf PR4
	movlw 0x00	; no pre/postscale, not yet enable.
	movwf T4CON
	banksel PIE3
	bcf PIE3,1  ; TMR4IE  disable int
	banksel TMR6
	movlw 0x1F	; loop 32
	movwf PR6
	movlw 0x00	; no pre/postscale, not yet enable.
	movwf T6CON
	banksel PIE3
	bcf PIE3,3  ; TMR6IE  disable int


	; prepare PWM registers, using CCPs 2 to 4 
	banksel CCPTMRS
	movf CCPTMRS,0
	andlw 0x03
	iorlw 0x90	; Tmr6 for PWM4, Tmr4 for PWM3, Tmr2 for PWM2.
	movwf CCPTMRS
	banksel CCP2CON
	movlw 0x0C		; select PWM mode, one output pin
	movwf CCP2CON
	movlw 0x10	; preload 50%
	movwf CCPR2L
	banksel CCP3CON
	movlw 0x0C		; select PWM mode, one output pin
	movwf CCP3CON
	movlw 0x10	; preload 50%
	movwf CCPR3L
	banksel CCP4CON
	movlw 0x0C		; select PWM mode, one output pin
	movwf CCP4CON
	movlw 0x10	; preload 50%
	movwf CCPR4L
	banksel 0


	clrf l_secondsL
	clrf l_secondsH

	; load frequency.
	; calc with python:
;lps = 8.0e6/64
;f = 440.0
;incr = int( 0x1000000 * f / lps + 0.5 )
;print "0x%06X" % (incr,)

	; 3520Hz   0x07357E
	movlw 0x7E
	movwf ml_freqLL
	movlw 0x35
	movwf ml_freqL
	movlw 0x07
	movwf ml_freqH
	; 10kHz   0x147AE1
	movlw 0xE1
	movwf ml_freqLL
	movlw 0x7A
	movwf ml_freqL
	movlw 0x14
	movwf ml_freqH

mainloop:

	; clear angle
	clrf ml_angleLL
	clrf ml_angleL
	clrf ml_angleH
	movlw 0xFF
	movwf ml_rndL
	movwf ml_rndH

	; start the timers and PWM
	banksel TMR2
	clrf TMR2
	bsf T2CON,2	; start
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	banksel TMR4
	clrf TMR4
	bsf T4CON,2	; start
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	banksel TMR6
	clrf TMR6
	bsf T6CON,2	; start
	banksel 0

	bcf PIR1,1		; TMR2IF

	; wait for one loop
	btfss PIR1,1		; TMR2IF
	bra $-1
	; enable output pins
	banksel TRISA
	bcf TRISA,portA_outpin_PWM2
	bcf TRISA,portA_outpin_PWM3
	bcf TRISA,portA_outpin_PWM4
	bcf TRISB,portB_led
	banksel 0

	; send 'P'
	banksel TXREG
	movlw 'P'
	movwf TXREG
	banksel 0

	movlw 0x80
	movwf ml_value
	movlw 0x10
	movwf ml_val_Preg
	movlw 0x0C
	movwf ml_val_Pcon

	; sync tmr4, so tmr2 will cycle while progging regs of PWM3,4
	bcf PIR3,3		; TMR6IF
	btfss PIR3,3		; TMR6IF
	bra $-1
	nop
	nop
	nop
	nop
	nop


;	call mainloop_10k_sin_and_noise
;	call mainloop_sinus_sweep_linear
	call mainloop_highpassed_noise


	; stop PWM, disable output pin
	banksel TRISA
	bsf TRISA,portA_outpin_PWM2
	bsf TRISA,portA_outpin_PWM3
	bsf TRISA,portA_outpin_PWM4
	bsf TRISB,portB_led
	movlw 0x10	; load 50%
	banksel CCP2CON
	movwf CCPR2L
	banksel CCP3CON
	movwf CCPR3L
	movwf CCPR4L
	banksel T2CON
	bcf T2CON,2
	banksel T4CON
	bcf T4CON,2
	banksel T6CON
	bcf T6CON,2
	banksel 0


	banksel 0


	bra mainloop




mainloop_10k_sin_and_noise:
	banksel 0
	incf ml_temp2,1
	; this is the 64-cycle timed loop
innerloop1_l:
	nop
	nop
innerloop1_h:

	; .0
	; write reg-vals
	banksel CCP2CON
	movf ml_val_Preg,0
	movwf CCPR2L
	movf ml_val_Pcon,0
	movwf CCP2CON
	banksel CCP3CON
	movf ml_val_Preg,0
	movwf CCPR3L
	movwf CCPR4L
	movf ml_val_Pcon,0
	movwf CCP3CON
	movwf CCP4CON
	banksel 0

	; .13
	; process CRC-16 reg
	lslf ml_rndL,1
	rlf ml_rndH,1
	movlw low RND_POLY_16
	btfsc STATUS,C
	xorwf ml_rndL,1
	movlw high RND_POLY_16
	btfsc STATUS,C
	xorwf ml_rndH,1

	; .21
	; increment sin-counter.
	movf ml_freqLL,0
	addwf ml_angleLL,1
	movf ml_freqL,0
	addwfc ml_angleL,1
	movf ml_freqH,0
	addwfc ml_angleH,1

	; .27

	; get sine-value
	movf ml_angleH,0
	movlp high getSine8bitSigned_256circle
	call getSine8bitSigned_256circle
	movlp 0
	xorlw 0x80

	movwf ml_value

	; .38
	lsrf ml_value,1
	movlw 0x40
	addwf ml_value,1
	movf ml_rndL,0
	addwf ml_value,1
	rrf ml_value,1

	; .44
	nop

	nop
	nop
	nop

	; .48

	; convert value from ml_value to reg-vals
	lsrf ml_value,0
	lsrf WREG,0
	lsrf WREG,0
	movwf ml_val_Preg
	lslf ml_value,0
	lslf WREG,0
	lslf WREG,0
	andlw 0x30
	iorlw 0x0C
	movwf ml_val_Pcon
	clrwdt

	; .59
	nop	; debug insert for endless loop.     decfsz ml_temp,1
	bra innerloop1_l
	decfsz ml_temp2,1
	bra innerloop1_h

	return






mainloop_sinus_sweep_linear:
	; freq will loop from 0 to 0x400000 : from 0 to 0.25*125kHz (31250Hz)
	; time for one sweep-loop: 1.048576 seconds (1<<13 loops, freq increment is 0x20)
	banksel 0
	incf ml_temp2,1
	; this is the 64-cycle timed loop
innerloop2_l:
	nop
	nop
innerloop2_h:

	; .0
	; write reg-vals
	banksel CCP2CON
	movf ml_val_Preg,0
	movwf CCPR2L
	movf ml_val_Pcon,0
	movwf CCP2CON
	banksel CCP3CON
	movf ml_val_Preg,0
	movwf CCPR3L
	movwf CCPR4L
	movf ml_val_Pcon,0
	movwf CCP3CON
	movwf CCP4CON
	banksel 0

	; .13
	; increment frequency
	movlw 0x20
	addwf ml_freqLL,1
	movlw 0x00
	addwfc ml_freqL,1
	movlw 0x00
	addwfc ml_freqH,1

	; limit
	movlw 0x3F
	andwf ml_freqH,1



	; .21
	; increment sin-counter.
	movf ml_freqLL,0
	addwf ml_angleLL,1
	movf ml_freqL,0
	addwfc ml_angleL,1
	movf ml_freqH,0
	addwfc ml_angleH,1

	; .27

	; get sine-value
	movf ml_angleH,0
	movlp high getSine8bitSigned_256circle
	call getSine8bitSigned_256circle
	movlp 0
	xorlw 0x80

	movwf ml_value

	; .38
	lsrf ml_value,1
	movlw 0x40
	addwf ml_value,1


	; .41
	nop
	nop
	nop
	nop

	nop
	nop
	nop

	; .48

	; convert value from ml_value to reg-vals
	lsrf ml_value,0
	lsrf WREG,0
	lsrf WREG,0
	movwf ml_val_Preg
	lslf ml_value,0
	lslf WREG,0
	lslf WREG,0
	andlw 0x30
	iorlw 0x0C
	movwf ml_val_Pcon
	clrwdt

	; .59
	nop	; debug insert for endless loop.     decfsz ml_temp,1
	bra innerloop2_l
	decfsz ml_temp2,1
	bra innerloop2_h

	return






mainloop_highpassed_noise:
	banksel 0
	incf ml_temp2,1
	; this is the 64-cycle timed loop
innerloop3_l:
	nop
	nop
innerloop3_h:

	; .0
	; write reg-vals
	banksel CCP2CON
	movf ml_val_Preg,0
	movwf CCPR2L
	movf ml_val_Pcon,0
	movwf CCP2CON
	banksel CCP3CON
	movf ml_val_Preg,0
	movwf CCPR3L
	movwf CCPR4L
	movf ml_val_Pcon,0
	movwf CCP3CON
	movwf CCP4CON
	banksel 0

	; .13
	; process CRC-16 reg
	lslf ml_rndL,1
	rlf ml_rndH,1
	movlw low RND_POLY_16
	btfsc STATUS,C
	xorwf ml_rndL,1
	movlw high RND_POLY_16
	btfsc STATUS,C
	xorwf ml_rndH,1

	; .21
	; calc tmp3/4 * 0.75
	lsrf ml_temp4,1
	rrf ml_temp3,1
	lsrf ml_temp4,0
	movwf l_Ah
	rrf ml_temp3,0
	addwf ml_temp3,1
	movf l_Ah,0
	addwfc ml_temp4,1
	; add 0.25*rndval without upper bits. (doesn't matter which bits to add)
	lsrf ml_rndH,0
	movwf l_Ah
	rrf ml_rndL,0
	movwf l_Al
	lsrf l_Ah,1
	rrf l_Al,0
	addwf ml_temp3,1
	movf l_Ah,0
	addwfc ml_temp4,1

	; .38
	; sub rndval - lowpass
	movf ml_temp3,0
	subwf ml_rndL,0
	movf ml_temp4,0
	subwf ml_rndH,0
	rrf WREG,0
	nop;xorlw 0x80
	movwf ml_value

	; 45
	nop
	nop
	nop

	; .48

	; convert value from ml_value to reg-vals
	lsrf ml_value,0
	lsrf WREG,0
	lsrf WREG,0
	movwf ml_val_Preg
	lslf ml_value,0
	lslf WREG,0
	lslf WREG,0
	andlw 0x30
	iorlw 0x0C
	movwf ml_val_Pcon
	clrwdt

	; .59
	nop	; debug insert for endless loop.     decfsz ml_temp,1
	bra innerloop3_l
	decfsz ml_temp2,1
	bra innerloop3_h

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


	org 0x800

#include "mathTables.asm"

	end






