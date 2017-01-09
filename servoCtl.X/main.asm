; PIC16F1847 Configuration Bit Settings
#include "p16F1847.inc"


;config bits: internal osc, watchdog, brownout, powerup-timer
; CONFIG1
; __config 0xEF9C
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_ON & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_ON & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_ON
; CONFIG2
; __config 0xDBFF
 __CONFIG _CONFIG2, _WRT_OFF & _PLLEN_ON & _STVREN_ON & _BORV_HI & _LVP_OFF


; vars on all banks
ml_temp          = 0x70		; used by any subrt.
ml_temp2         = 0x71		; used by any subrt.
ml_temp3         = 0x72		; used by 'bigger' subrt.
ml_temp4         = 0x73		; used by 'bigger' subrt.
ml_timeCount     = 0x74		; advances 50/sec

ml_TXSbitcount  = 0x75
ml_TXSshiftreg  = 0x76


; vars bound to bank 0
l_Al             = 0x20
l_Ah             = 0x21
l_Bl             = 0x22
l_Bh             = 0x23
l_Cl             = 0x24
l_Ch             = 0x25
l_Dl             = 0x26
l_Dh             = 0x27

l_lastRXtime0   = 0x28

l_secondsL       = 0x2A
l_secondsH       = 0x2B

l_bufTXin        = 0x2C
l_bufTXout       = 0x2D
l_bufRXin        = 0x2E

l_lopSBfram   = 0x2F

l_nextMeasure    = 0x30	; compared against l_secondsH
l_parityErrorsRX = 0x31

l_lastFrameBad   = 0x32
l_signalLost     = 0x33

l_flippinC       = 0x34
l_flippinT       = 0x35

l_modeSwitch    = 0x36
l_filterFirst   = 0x37

l_framBuf1        = 0x38 ; .28 bytes
l_framBuf2        = 0x54 ; .28 bytes


portA_pwm = 4

portB_led = 0
portB_RX = 2

portB_TX = 5

LATS1 = LATA
portbit_S1 = 6
LATS2 = LATA
portbit_S2 = 7
LATS3 = LATA
portbit_S3 = 0
LATS4 = LATA
portbit_S4 = 1
LATS5 = LATA
portbit_S5 = 2
LATS6 = LATA
portbit_S6 = 3
LATS7 = LATA
portbit_S7 = 5
LATS8 = LATA
portbit_S8 = 5
LATS9 = LATA
portbit_S9 = 5
LATS10 = LATA
portbit_S10 = 5
LATS11 = LATA
portbit_S11 = 5
LATS12 = LATA
portbit_S12 = 5
LATS13 = LATA
portbit_S13 = 5
LATS14 = LATA
portbit_S14 = 5
LATS15 = LATA
portbit_S15 = 5
LATS16 = LATA
portbit_S16 = 5



; on 1k-mem
;bufferTX = 0x2200
;bufferTXend = 0x2280
;bufferRX = 0x2280
;bufferRXend = 0x2300
;bufferTXS = 0x2300
;bufferTXSend = 0x2378
;bufferRXS = 0x2378
;bufferRXSend = 0x23F0

; on 256-b mem
l_servoValuesBuffer = 0x0A0	; 2*.18 bytes    0x2050 .. 0x2074
l_servoPWMdata = 0x2074		; size 16*3 .. 0x20A4

bufferRX = (l_framBuf1)
bufferRXend = (l_framBuf1+.28)
bufferTX = 0x20F0
bufferTXend = 0x21E8
; next buffer was up to 0x2228



	org 0
	goto skipToSetup

;===============================================================================

	org 4
	banksel 0		; assume entering int after +2 cycles

	retfie


;===============================================================================

skipToSetup:


	; oscillator setup ..... To get 32MHz internal, FOSC=100 (INTOSC), SCS=00 (source=INTOSC), IRCF=1110 (8MHz), SPLLEN=1 (PLLEN)
	movlw 0xF0	; PLL on, int osc 8MHz, clockselect by config.
	banksel OSCCON
	movwf OSCCON
	banksel 0

	movlb .31
	movf 0x20,0	; PICsim-control in 0x0FA0
	banksel 0
	btfsc WREG,0
	bra skipPauseOsc
	movlw 0xC8
pauseOsc:
	nop
	nop
	decfsz WREG,0
	bra pauseOsc
skipPauseOsc:


	; port setup
	banksel ANSELA
	clrf ANSELA
	clrf ANSELB
	banksel WPUA
	movlw 0xFF
	movwf WPUA
	movwf WPUB
	banksel OPTION_REG
	bcf OPTION_REG,7		; ~WPUEN
	banksel LATB
	clrf LATA
	bcf LATB,portB_led
	banksel TRISA
	movlw 0x20
	movwf TRISA
	movlw 0xFF-(1<<portB_TX)-(1<<portB_led)
	movwf TRISB
	banksel IOCBF
	clrf IOCBP
	banksel 0

	; UART setup (no interrupts!)
	banksel APFCON0
	bsf APFCON1,0		; TXCKSEL: move UART TX to B5
	bsf APFCON0,7		; RXDTSEL: move UART RX to B2

	; UART BAUD rate setup.
	; formula for baudrate value:
	;  32e6/(4*100000)-1     for S-bus rate  =  79
	;  32e6/(4*115200)-1     for 115k2 rate  =  68.44
	;  32e6/(4* 57600)-1     for 115k2 rate  = 137.89
	banksel BAUDCON
	movlw 0x48
	movwf BAUDCON		; RCIDL (BRG16=1)
	banksel TXSTA
	bcf TXSTA,4	; SYNC
	bsf TXSTA,2 ; BRGH
	; Set to 100.0 kBaud.
	banksel SPBRGL
	movlw .68      ;  for 100kbaud, .79      for 115k2baud, .68
	movwf SPBRGL
	movlw 0x00
	movwf SPBRGH

	; UART TX
	banksel BAUDCON
	banksel TXSTA
;	bsf TXSTA,6	; TX9 (enable 9-bit)
	bsf TXSTA,5	; TXEN (go)
	banksel RCSTA
	bsf RCSTA,7	; SPEN

	; UART RX setup.
	banksel RCSTA
;	bsf RCSTA,6 ; RX9 (enable 9-bit)
	bsf RCSTA,4 ; CREN (go!)
	banksel PIE1
	bcf PIE1,5	; without intrr

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

	; timer4 is for PWM. 3906.25 loops/sec @ 8MHz
	banksel TMR4
	movlw 0xFF	; full range for 10-bit resolution.
	movwf PR4
	movlw 0x05  ; prescale=1:4, enable
	movwf T4CON

	; timer 6 is timer for getting clean 200 PWM outputs per second. (or 100)
	; that is 40000 ticks/loop. 
	banksel TMR6
	movlw .125 ; 125 is good divisor for powers of ten.
	movwf PR6
	movlw 0x07+8*(5-1)  ; prescale=1:64, enable, postscale is 5 for 200Hz, 10 for 100Hz.
	movwf T6CON

	; timer 0 is the timer for detecting gaps in the S-bus bursts.
	banksel 0
	bcf INTCON,5	; disable int on timer 0
	banksel OPTION_REG
	movf OPTION_REG,0
	andlw 0xD0
	iorlw 0x06	; TMR0CS=0 , PSA=0, PS=1:128
	movwf OPTION_REG
	banksel TMR0
	; no enable bit??? already running?

	; CCP4 as PWM on timer4
	banksel CCPTMRS
	movlw 0x0F
	andwf CCPTMRS,1
	movlw 0x50	; select timer 4 for CCP3 and CCP4
	iorwf CCPTMRS,1
	banksel CCP4CON
	movlw 0x0C		; enable PWM for CCP4
	movwf CCP4CON

	banksel TRISA
	bcf TRISA,portA_pwm

	banksel 0

	; startup-pause
	movlb .31
	movf 0x20,0	; PICsim-control in 0x0FA0
	banksel 0
	btfsc WREG,0
	bra skipStartPause
	movlw 0x07
	movwf ml_temp4
	clrf ml_temp3
	clrf WREG
startPause:
	nop
	nop
	decfsz WREG,0
	bra startPause
	decfsz ml_temp3,1
	bra startPause
	decfsz ml_temp4,1
	bra startPause
skipStartPause:


	; Vars setup
	banksel 0
	clrf l_bufTXin
	clrf l_bufTXout
	clrf l_bufRXin
	clrf l_parityErrorsRX
	clrf ml_TXSbitcount
	clrf ml_timeCount
	clrf l_secondsL
	clrf l_secondsH
	clrf l_parityErrorsRX
	clrf l_flippinC
	clrf l_flippinT
	movlw 1
	movwf l_modeSwitch
	movlw .10
	movwf l_filterFirst

	; preload TX buffer
	movlw 'S'
	call putTX
	movlw 'b'
	call putTX
	movlw 'u'
	call putTX
	movlw 's'
	call putTX
	movlw 0x0D
	call putTX
	movlw 0x0A
	call putTX


	; act ints
	banksel PIE1
	clrf PIE1
	clrf PIE2
	clrf PIE3
	clrf PIE4
	banksel IOCBF
	clrf IOCBF

	banksel 0
	bcf PIR3,3		; TMR6IF

	banksel 0
	clrf l_Dl
	clrf l_Dh

	movlw 0xC0
	movwf INTCON	; GIE+PEIE

	clrwdt
	banksel WDTCON
	movlw 0x0E
	movwf WDTCON		; watchdog to 128ms
	banksel 0

mainloop:
	banksel 0

	movf l_Dl,0			; if secondsH == Dl, inc Dl and output something,
	subwf l_secondsH,0
	btfss STATUS,Z
	bra noPutTXS
	incf l_Dl,1
;	movf l_bufRXin,0
;	addlw 'a'
;	;movlw '.'
;	call putTX

;	movf l_Dl,0
;	call $+3
;	call putTX
;	bra noPutTXS
;	andlw 0x07
;	brw
;	retlw '0'
;	retlw '1'
;	retlw '2'
;	retlw '3'
;	retlw '4'
;	retlw '.'
;	retlw 0x0D
;	retlw 0x0A
noPutTXS:



	banksel 0

	; timer tick
	banksel 0
	btfss PIR1,1		; TMR2IF
	bra $+3
	bcf PIR1,1		; TMR2IF
	incf ml_timeCount,1

	clrwdt

	; check/increment l_seconds
	banksel 0
	movlw 0x32
	subwf ml_timeCount,0
	btfss STATUS,C
	bra $+5	; no full second
	clrf ml_timeCount
	incf l_secondsH,1
	movlw '.'
	call putTX
	; calc 5.125*timecount
	lslf ml_timeCount,0
	lslf WREG,0
	addwf ml_timeCount,0
	movwf l_secondsL
	lsrf ml_timeCount,0
	lsrf WREG,0
	lsrf WREG,0
	addwf l_secondsL,1

;	movf l_secondsL,0
;	banksel CCPR4L
;	movwf CCPR4L
;	banksel 0

	; alive-LED  bit #-1 of seconds counter.
	movf l_secondsL,0
	movwf ml_temp
	banksel TRISB
	movf TRISB,0
	bcf WREG,portB_led
	btfsc ml_temp,7
	bsf WREG,portB_led
	movwf TRISB
	banksel 0

	; check RX and TX flags
	call testRXTX

	; timeout?		; one RX byte every 7.5 TMR0 ticks. timeout at 20.
	movf l_lastRXtime0,0
	subwf TMR0,0
	sublw .20
	btfsc STATUS,C
	bra $+5
	clrf l_bufRXin	; timeout. drop all.
	clrf l_parityErrorsRX
	banksel RCSTA
	btfsc RCSTA,1	; OERR
	bcf RCSTA,4		; CREN
	bsf RCSTA,4		; CREN
	banksel 0
	movf TMR0,0
	movlw l_lastRXtime0

;		; have input frame?
;		call haveRX
;		btfsc STATUS,Z
;		bra $+3
;		addlw 'a'
;		call putTX

	; have input frame?
	call haveRX
	sublw .25-1
	btfss STATUS,C

	call processRXframe


	; timer6 expired? output servo pulses?
	banksel 0
	btfss PIR3,3		; TMR6IF
	bra noSendServoPwm
	bcf PIR3,3		; TMR6IF
	; pick up how much T6 is over already.
	; assuming mainloop time of at most 2k cycles. hopefully. So calc 64*(.32-TMR6) and delay so much to sync.
	banksel TMR6
	movf TMR6,0
	sublw .32
	btfss STATUS,C
	movlw 0
	banksel 0
	movwf l_Ah ; multiply with 64 (prescaler)
	clrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	call delay_Alh

	;call prepareAndSendServoPWM



noSendServoPwm:

	bra mainloop


;===============================================================================

processRXframe:
	; data is in l_framBuf1

;	movlw 'H'
;	call putTX
;	movlw 0x0D
;	call putTX
;	movlw 0x0A
;	call putTX

	; run decoder
	movf l_parityErrorsRX,0
;	btfss STATUS,Z
;	bsf l_framBuf1+.23,2	; framing error bit
	movlw low l_servoValuesBuffer
	movwf FSR1L
	movlw high l_servoValuesBuffer
	movwf FSR1H
	call decodeSbusFrame	;; takes roughly 230
	movwf ml_temp2
	call testRXTX	; the decoder took some time...

	movf ml_temp2,0
	btfsc STATUS,Z
	bra decodedBad

	; place one on hardware-PWM
	banksel l_servoValuesBuffer
	movf l_servoValuesBuffer+4,0
	movwf ml_temp
	movf l_servoValuesBuffer+5,0
	movwf ml_temp2
	call placeOnPwm

	banksel 0

	; timer-tick
	bra $+3
	bcf PIR1,1		; TMR2IF
	incf ml_timeCount,1
	clrwdt

	; This takes forever. If UART stuff comes in here, we're down.
	call prepareAndSendServoPWM

	call testRXTX

	; timer-tick
	bra $+3
	bcf PIR1,1		; TMR2IF
	incf ml_timeCount,1
	clrwdt


	call testRXTX



;	clrf ml_temp3
;debugoutputSome:
;	lslf ml_temp3,0
;	movwf FSR1L
;	clrf FSR1H
;	movlw low l_servoValuesBuffer
;	addwf FSR1L,1
;	movlw high l_servoValuesBuffer
;	addwfc FSR1H,1
;	moviw 1[FSR1]
;	call putHexTX_half
;	moviw 0[FSR1]
;	call putHexTX
;	movlw 0x20
;	call putTX
;
;	incf ml_temp3,1
;	movlw 4
;	subwf ml_temp3,0
;	btfss STATUS,C
;	bra debugoutputSome

	banksel l_servoValuesBuffer
	movf l_servoValuesBuffer+.1,0
	banksel 0
	call putHexTX
	banksel l_servoValuesBuffer
	movf l_servoValuesBuffer+.0,0
	banksel 0
	call putHexTX
	movlw 0x20
	call putTX
	banksel l_servoValuesBuffer
	movf l_servoValuesBuffer+.3,0
	banksel 0
	call putHexTX
	banksel l_servoValuesBuffer
	movf l_servoValuesBuffer+.2,0
	banksel 0
	call putHexTX
	movlw 0x20
	call putTX

	movlw 0x0D
	call putTX
	movlw 0x0A
	call putTX


	clrf l_bufRXin	; drop all.
	clrf l_parityErrorsRX
	movf TMR0,0
	movlw l_lastRXtime0

	bra decodedDone
decodedBad:
	movlw 'B'
	call putTX
	movlw 'a'
	call putTX
	movlw 'd'
	call putTX
	movlw 0x0A
	call putTX
	movlw 0x0A
	call putTX

	bra decodedDone

decodedDone:
	return


putHexTX_half:
	movwf ml_temp2
	bra $+8
putHexTX:
	movwf ml_temp2
	lsrf WREG,0
	lsrf WREG,0
	lsrf WREG,0
	lsrf WREG,0
	call getHexDigit
	call putTX
	movf ml_temp2,0
	call getHexDigit
	goto putTX

getHexDigit:
	andlw 0x0F
	brw
	dw 0x3430,0x3431,0x3432,0x3433,0x3434,0x3435,0x3436,0x3437
	dw 0x3438,0x3439,0x3441,0x3442,0x3443,0x3444,0x3445,0x3446

;===============================================================================

placeOnPwm:
	; value to place in ml_temp:ml_temp2

	; double
	movlw 2
	subwf ml_temp2,0
	btfss STATUS,C
	bra __pop_cutlow
	movlw 6
	subwf ml_temp2,0
	btfsc STATUS,C
	bra __pop_cuthigh
	movlw 2
	subwf ml_temp2,1
	bra $+8
__pop_cutlow:
	clrf ml_temp
	clrf ml_temp2
	bra $+5
__pop_cuthigh:
	movlw 0xFF
	movwf ml_temp
	movlw 0x03
	movwf ml_temp2

	lslf ml_temp,1
	rlf ml_temp2,1


;; wait for timer to reach almost end.
;	banksel TMR4
;	movlw 0xEE
;	subwf TMR4,0
;	btfsc STATUS,C
;	bra $-3

	banksel CCP4CON
	lsrf ml_temp2,1
	rrf ml_temp,0
	lsrf ml_temp2,1
	rrf WREG,0
	lsrf ml_temp2,1
	rrf WREG,0
	bcf CCP4CON,4
	bcf CCP4CON,5

	btfsc ml_temp,1		; contranry to docu, this does not work with 1:1 prescaler.
	bsf CCP4CON,4
	btfsc ml_temp,2
	bsf CCP4CON,5

	movwf CCPR4L
	banksel 0
	return


;===============================================================================

delay_Alh:
	; delay variable amount, value in l_Al,l_Ah.
	; includes time for call and return.
	; does not include setup-time for l_Al/l_Ah.
	; minimum is 13 cycles.
	; if request is too short, returns number of cycles over.
	; if sufficiently large, calls testRX with W=0 (constant time variant)

	movlw 0xC0
	andwf l_Al,0
	iorwf l_Ah,0
	btfss STATUS,Z
	bra delay_Alh_high
	; wenn reaching this point, we already used 7 not counted (incl 2 for call-in)
	movf l_Al,0
	xorlw 0x3F
	brw		; with brw and return, have a total of 7+2+2+2=13 not counted.

	nop ; param = 63
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop ; param = 55
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop ; param = 47
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop ; param = 39
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop ; param = 31
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop ; param = 23
	nop
	nop
	nop
	nop
	nop
	nop
	nop	; a param of 16 would hop here. need 3 nops then

	nop ; param = 15
	nop
	retlw 0x00 ; param = 13
	retlw 0x01
	retlw 0x02
	retlw 0x03
	retlw 0x04
	retlw 0x05

	retlw 0x06 ; param = 7
	retlw 0x07
	retlw 0x08
	retlw 0x09
	retlw 0x0A
	retlw 0x0B
	retlw 0x0C
	retlw 0x0D

	retlw 0x7F
	retlw 0x7F
delay_Alh_high:
	; Do a call to testRX
	movlw 0
	call testRX

	movlw .13 + testRX__exectime   ; this must be <= 13, the minimum delay execution time.
	subwf l_Al,1
	movlw 0
	subwfb l_Ah,1
	bra delay_Alh

;===============================================================================

testRXTX:
	call testTX
	movlw 1
	call testRX
	btfss WREG,0
	bra $+3
	movf TMR0,0
	movwf l_lastRXtime0
	return


;===============================================================================

#include "servoPWM.asm"
#include "sbusFrameCodec.asm"
#include "uartBuffer.asm"


	end



