; PIC16F1847 Configuration Bit Settings
#include "p16F1847.inc"


;config bits: internal osc, watchdog, brownout, powerup-timer
; CONFIG1
; __config 0xEF9C
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_ON & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_ON & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_ON
; CONFIG2
; __config 0xDBFF
 __CONFIG _CONFIG2, _WRT_OFF & _PLLEN_ON & _STVREN_ON & _BORV_HI & _LVP_OFF

; switch for 200Hz mode.
use200Hz = 0

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

l_CRCstate      = 0x28

l_secondsL       = 0x29
l_secondsH       = 0x2A

l_bufTXin        = 0x2B
l_bufTXout       = 0x2C
l_bufRXin        = 0x2D
l_bufRXout       = 0x2E

l_nextMeasure    = 0x2F	; compared against l_secondsH

l_tickTMR6cnt    = 0x30
l_ticks_wo_data  = 0x31

l_lastFrameBad   = 0x32
l_signalLost     = 0x33

l_flippinC       = 0x34
l_flippinT       = 0x35

l_modeSwitch    = 0x36
l_filterFirst   = 0x37

l_framBufCnt = 0x38
l_framBuf        = 0x39	; for processing RX frames
l_framBufEnd     = 0x70 ; max 0x37 bytes

l_framBuf1 = l_framBuf ; ...... remove this along with sbus-decoder.
l_framBuf2 = l_framBuf ; ...... remove this along with sbus-decoder.

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
portbit_S7 = 4
LATS8 = LATB
portbit_S8 = 1
LATS9 = LATB
portbit_S9 = 3
LATS10 = LATB
portbit_S10 = 4
LATS11 = LATB
portbit_S11 = 6
LATS12 = LATB
portbit_S12 = 7
LATS13 = LATA
portbit_S13 = 5
LATS14 = LATA
portbit_S14 = 5
LATS15 = LATA
portbit_S15 = 5
LATS16 = LATA
portbit_S16 = 5


; buffers. start at second bank 0x2050 , up to end @ 0x23F0

l_servoValuesBuffer = 0x0A0	; 4*.16 bytes    0x2050 .. 0x2090
l_servoPWMdata = 0x2090		; size 16*3 .. 0x20C0

bufferRX = 0x20C0
bufferRXend = 0x2180
bufferTX = 0x2180
bufferTXend = 0x2240



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
	bsf TXSTA,5	; TXEN (go)
	banksel RCSTA
	bsf RCSTA,7	; SPEN

	; UART RX setup.
	banksel RCSTA
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

	; timer 6 is timer for getting clean 200 PWM outputs per second. (or 100)
	; that is 40000 ticks/loop. 
	banksel TMR6
	movlw .125 ; 125 is good divisor for powers of ten.
	movwf PR6
	movlw 0x07+8*(5-1)  ; prescale=1:64, enable, postscale is 5 for 200Hz, 10 for 100Hz.
	movwf T6CON


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
	clrf l_bufRXout
	clrf ml_TXSbitcount
	clrf ml_timeCount
	clrf l_secondsL
	clrf l_secondsH
	clrf l_flippinC
	clrf l_flippinT
	clrf l_framBufCnt
	movlw 1
	movwf l_modeSwitch
	movlw .10
	movwf l_filterFirst
	clrf l_tickTMR6cnt
	movlw 0xFF
	movwf l_ticks_wo_data

	movlw low l_servoValuesBuffer
	movwf FSR0L
	movlw high l_servoValuesBuffer
	movwf FSR0H
	movlw .12
	movwf ml_temp
_clr_servo_values:
	movlw 0
	movwi 0[FSR0]
	movwi 2[FSR0]
	movwi 3[FSR0]
	movlw 0x80
	movwi 1[FSR0]
	addfsr FSR0,4
	decfsz ml_temp,1
	bra _clr_servo_values


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

	; do some stuff once a second...


;	; adjust servos a little.
;	movlw low l_servoValuesBuffer
;	movwf FSR0L
;	movlw high l_servoValuesBuffer
;	movwf FSR0H
;	movf l_secondsH,0
;	andlw .3
;	addlw .2
;	lslf WREG,0
;	iorlw 1
;	lslf WREG,0
;	lslf WREG,0
;	lslf WREG,0
;	lslf WREG,0
;	movwi 1[FSR0]
;	movlw 0
;	movwi 0[FSR0]


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
	call testRX_OERR

	; pick up input data to recv buffer.
	banksel 0
	movlw high l_framBuf
	movwf FSR1H
	movlw low l_framBuf
	movwf FSR1L
	movf l_framBufCnt,0
	addwf FSR1L,1
	btfsc STATUS,C
	incf FSR1H,1
	; get data, up to packet-size of .40
	movlw .10
	call getRX_many
	addwf l_framBufCnt,1
	movlw .40
	subwf l_framBufCnt,0
	btfsc STATUS,C
	call checkRXdata

	; check RX and TX flags
	call testRXTX




_tytRx_rest:
_tytRx_done:

;		; have input frame?
;		call haveRX
;		btfsc STATUS,Z
;		bra $+3
;		addlw 'a'
;		call putTX


	; timer6 expired? output servo pulses?
	banksel 0
	btfss PIR3,3		; TMR6IF
	bra noSendServoPwm
	bcf PIR3,3		; TMR6IF
	; count event
	incf l_tickTMR6cnt,1
	incf l_ticks_wo_data,1
	btfsc STATUS,Z
	decf l_ticks_wo_data,1

 if use200Hz==0	; if not 200Hz, skip every second call
	btfsc l_tickTMR6cnt,0
	bra _skip_genPWM
 endif
	; if have not seen data for a while, do not send.
	movlw .30
	subwf l_ticks_wo_data,0
	btfsc STATUS,C
	bra _skip_genPWM


	; pick up how much T6 is over already.
	; assuming mainloop time of at most 2k cycles. hopefully. So calc 64*(.32-TMR6) and delay so much to sync.
	banksel TMR6
	movf TMR6,0
	sublw .32
	btfss STATUS,C
	movlw 0
	banksel 0
	movwf l_Ah ; multiply with 64 (prescaler)
	clrf l_Al
	lsrf l_Ah,1
	rrf l_Al,1
	lsrf l_Ah,1
	rrf l_Al,1
	call delay_Alh

	call prepareAndSendServoPWM

	call testRXTX

;	call DEBUG_output_value
_skip_genPWM:

	; if last data-send is not too long ago, add the speed values.
	movlw .25
	subwf l_ticks_wo_data,0
	btfss STATUS,C
	call add_servo_speedval

	call testRX

noSendServoPwm:

	bra mainloop

;===============================================================================

add_servo_speedval:
	banksel 0
	movlw low l_servoValuesBuffer
	movwf FSR1L
	movlw high l_servoValuesBuffer
	movwf FSR1H
	movlw .12	; ..... constant for num channels?
	movwf ml_temp2
_add_speed:
	; get and sign-extend speed
	clrf ml_temp
	moviw 2[FSR1]
	movwf l_Al
	moviw 3[FSR1]
	movwf l_Ah
	btfsc WREG,7
	decf ml_temp,1
	; get and add value
	moviw 0[FSR1]
	addwf l_Al,1
	moviw 1[FSR1]
	addwfc l_Ah,1
	movlw 0
	addwfc ml_temp,1
	; check bounds.
	movf ml_temp,0
	btfsc STATUS,Z
	bra _add_no_clamp
	clrf l_Al
	clrf l_Ah
	btfss WREG,7
	decf l_Al,1
	btfss WREG,7
	decf l_Ah,1
_add_no_clamp:
	movf l_Al,0
	movwi 0[FSR1]
	movf l_Ah,0
	movwi 1[FSR1]

	addfsr FSR1,4
	decfsz ml_temp2,1
	bra _add_speed
	return

;===============================================================================

checkRXdata:
	; called when having at least 22 bytes.
	movlw low l_framBuf
	movwf FSR0L
	movlw high l_framBuf
	movwf FSR0H
	moviw 0[FSR0]
	xorlw 'S'
	btfss STATUS,Z
	bra _checkRX_badhead
	moviw 1[FSR0]
	xorlw 0
	btfss STATUS,Z
	bra _checkRX_badhead
	moviw 2[FSR0]
	xorlw .12
	btfss STATUS,Z
	bra _checkRX_badhead

	; poll
	movlw 1
	call testRX
	; calc CRC
	movlw 0xFF
	movwf l_CRCstate
	movf FSR0L,0
	movwf FSR1L
	movf FSR0H,0
	movwf FSR1H
	movlw .40-1
	movwf ml_temp
_calcCRC:
	moviw FSR1++
	xorwf l_CRCstate,0
	call _pollCRCtab
	movwf l_CRCstate
	decfsz ml_temp,1
	bra _calcCRC
	moviw 0[FSR1]
	xorwf l_CRCstate,0
	btfss STATUS,Z
	bra _checkRX_badhead
	; is valid!!
	movlw 'o'
	call putTX
	movlw 'k'
	call putTX
	movlw .13
	call putTX
	movlw .10
	call putTX

	; poll
	movlw 1
	call testRX

	; process it
	movlw low l_servoValuesBuffer
	movwf FSR1L
	movlw high l_servoValuesBuffer
	movwf FSR1H
	call decodeFrame	;; takes roughly 440
	clrf l_ticks_wo_data

	; poll
	movlw 1
	call testRX



	; drop it
	movlw .40
	call dropRXdata
	retlw 1



_checkRX_badhead:
	; bad. scan for next 'S' in data.
	movlw 'b'
	call putTX
	movlw 'a'
	call putTX
	movlw 'd'
	call putTX
	movlw ' '
	call putTX

	; DEBUG output buffer  ..... delete!
	movlw low l_framBuf
	movwf FSR1L
	movlw high l_framBuf
	movwf FSR1H
	movlw .40
	movwf ml_temp2
	moviw FSR1++
	call putTX
	decfsz ml_temp2,1
	bra $-3

;	movf l_framBufCnt,0
;	call putHexTX

	movlw .13
	call putTX
	movlw .10
	call putTX


	; scan for 'S'
	movlw low l_framBuf
	movwf FSR0L
	movlw high l_framBuf
	movwf FSR0H
	movf l_framBufCnt,0
	movwf ml_temp
	clrf ml_temp2
	decf ml_temp,1 ; do not allow first.
	incf ml_temp2,1
	moviw FSR0++
_scan_S:
	moviw FSR0++
	xorlw 'S'
	btfsc STATUS,Z
	bra _scan_S_found
	incf ml_temp2,1
	decfsz ml_temp,1
	bra _scan_S
_scan_S_found:
	movf ml_temp2,0
	call dropRXdata
	retlw 0



dropRXdata:
	; W number to drop.
	banksel 0
	; limit value
	movwf ml_temp
	movf ml_temp,0
	btfsc STATUS,Z
	return
	movf l_framBufCnt,0
	subwf ml_temp,0
	movf l_framBufCnt,0
	btfsc STATUS,C
	bra dropRXdata_all
	; prepare copy-pointers. copy from [FSR1] to [FSR0]
	movlw low l_framBuf
	movwf FSR0L
	movlw high l_framBuf
	movwf FSR0H
	movf ml_temp,0
	addwf FSR0L,0
	movwf FSR1L
	movlw 0
	addwfc FSR0H,0
	movwf FSR1H
	movf ml_temp,0
	subwf l_framBufCnt,1
	movf l_framBufCnt,0
	movwf ml_temp
	moviw FSR1++
	movwi FSR0++
	decfsz ml_temp,1
	bra $-3
	return
dropRXdata_all:
	banksel 0
	clrf l_framBufCnt
	return

;===============================================================================


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

DEBUG_output_value:
	movlw low l_servoValuesBuffer
	movwf FSR1L
	movlw high l_servoValuesBuffer
	movwf FSR1H
	movlw '0'
	call putTX
	movlw 'x'
	call putTX
	moviw 1[FSR1]
	call putHexTX
	moviw 0[FSR1]
	call putHexTX
	movlw .13
	call putTX
	movlw .10
	call putTX
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

	movlw .13 + .23 ; ..... should be + testRX__exectime   ; this must be <= 13, the minimum delay execution time.
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
	return


;===============================================================================

_pollCRCtab:
	brw
	dw 0x3400,0x34C2,0x3471,0x34B3,0x34E2,0x3420,0x3493,0x3451,0x3431,0x34F3,0x3440,0x3482,0x34D3,0x3411,0x34A2,0x3460
	dw 0x3462,0x34A0,0x3413,0x34D1,0x3480,0x3442,0x34F1,0x3433,0x3453,0x3491,0x3422,0x34E0,0x34B1,0x3473,0x34C0,0x3402
	dw 0x34C4,0x3406,0x34B5,0x3477,0x3426,0x34E4,0x3457,0x3495,0x34F5,0x3437,0x3484,0x3446,0x3417,0x34D5,0x3466,0x34A4
	dw 0x34A6,0x3464,0x34D7,0x3415,0x3444,0x3486,0x3435,0x34F7,0x3497,0x3455,0x34E6,0x3424,0x3475,0x34B7,0x3404,0x34C6
	dw 0x347D,0x34BF,0x340C,0x34CE,0x349F,0x345D,0x34EE,0x342C,0x344C,0x348E,0x343D,0x34FF,0x34AE,0x346C,0x34DF,0x341D
	dw 0x341F,0x34DD,0x346E,0x34AC,0x34FD,0x343F,0x348C,0x344E,0x342E,0x34EC,0x345F,0x349D,0x34CC,0x340E,0x34BD,0x347F
	dw 0x34B9,0x347B,0x34C8,0x340A,0x345B,0x3499,0x342A,0x34E8,0x3488,0x344A,0x34F9,0x343B,0x346A,0x34A8,0x341B,0x34D9
	dw 0x34DB,0x3419,0x34AA,0x3468,0x3439,0x34FB,0x3448,0x348A,0x34EA,0x3428,0x349B,0x3459,0x3408,0x34CA,0x3479,0x34BB
	dw 0x34FA,0x3438,0x348B,0x3449,0x3418,0x34DA,0x3469,0x34AB,0x34CB,0x3409,0x34BA,0x3478,0x3429,0x34EB,0x3458,0x349A
	dw 0x3498,0x345A,0x34E9,0x342B,0x347A,0x34B8,0x340B,0x34C9,0x34A9,0x346B,0x34D8,0x341A,0x344B,0x3489,0x343A,0x34F8
	dw 0x343E,0x34FC,0x344F,0x348D,0x34DC,0x341E,0x34AD,0x346F,0x340F,0x34CD,0x347E,0x34BC,0x34ED,0x342F,0x349C,0x345E
	dw 0x345C,0x349E,0x342D,0x34EF,0x34BE,0x347C,0x34CF,0x340D,0x346D,0x34AF,0x341C,0x34DE,0x348F,0x344D,0x34FE,0x343C
	dw 0x3487,0x3445,0x34F6,0x3434,0x3465,0x34A7,0x3414,0x34D6,0x34B6,0x3474,0x34C7,0x3405,0x3454,0x3496,0x3425,0x34E7
	dw 0x34E5,0x3427,0x3494,0x3456,0x3407,0x34C5,0x3476,0x34B4,0x34D4,0x3416,0x34A5,0x3467,0x3436,0x34F4,0x3447,0x3485
	dw 0x3443,0x3481,0x3432,0x34F0,0x34A1,0x3463,0x34D0,0x3412,0x3472,0x34B0,0x3403,0x34C1,0x3490,0x3452,0x34E1,0x3423
	dw 0x3421,0x34E3,0x3450,0x3492,0x34C3,0x3401,0x34B2,0x3470,0x3410,0x34D2,0x3461,0x34A3,0x34F2,0x3430,0x3483,0x3441

;===============================================================================

#include "servoPWM.asm"
#include "frameCodec.asm"
#include "uartBuffer.asm"


	end



