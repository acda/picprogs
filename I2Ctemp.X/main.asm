; PIC12F1840 Configuration Bit Settings
#include "p12F1840.inc"


;config bits: internal osc.
; CONFIG1
; __config 0x2FE4
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_ON
; CONFIG2
; __config 0x1FFF
 __CONFIG _CONFIG2, _WRT_OFF & _PLLEN_ON & _STVREN_ON & _BORV_LO & _LVP_OFF


NUM_LEDS = .54	; max 0x60!!!


; vars on all banks
ml_temp          = 0x70		; used by any subrt.
ml_temp2         = 0x71		; used by any subrt.
ml_temp3         = 0x72		; used by 'bigger' subrt.
ml_temp4         = 0x73		; used by 'bigger' subrt.
ml_timeCount     = 0x74		; advances 50/sec
ml_ledSequenceCount = 0x76
ml_txCount       = 0x78
ml_count         = 0x7A
ml_bitcount      = 0x7B

; vars bound to bank 0
l_Al             = 0x20
l_Ah             = 0x21
l_Bl             = 0x22
l_Bh             = 0x23
l_Cl             = 0x24
l_Ch             = 0x25
l_Dl             = 0x26
l_Dh             = 0x27
l_in16bitL       = 0x28
l_in16bitH       = 0x29
l_TempAl         = 0x30
l_TempAh         = 0x31
l_TempBl         = 0x32
l_TempBh         = 0x33
l_TempValid      = 0x38
l_secondsL       = 0x39
l_secondsH       = 0x3A
l_nextMeasure    = 0x3B	; compared against l_secondsH
l_colR         = 0x40
l_colG         = 0x41
l_colB         = 0x42
l_colH         = 0x43
l_colS         = 0x44
l_colV         = 0x45
l_tempmark     = 0x46
l_pos          = 0x47
l_X            = 0x48

l_bufTXin       = 0x50
l_bufTXout      = 0x51
l_bufRXin       = 0x52
l_bufRXout      = 0x53

l_scratch  = 0x58	; 8 bytes



; PIC 12F1840
portA_TX = 0
portA_I2Cc = 1
portA_I2Cd = 2
portA_pin = 4
portA_led = 5
portA_RX = 5

bufferLED = 0x2040		; size 2*NUM_LEDS, max 0x9A or 0x4D LEDs (=77d)

bufferTX = 0x20DA
bufferTXend = 0x20EE
bufferRX = 0x20EE
bufferRXend = 0x20F0


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

	movlw 0xC8
pauseOsc:
	nop
	nop
	decfsz WREG,0
	bra pauseOsc

	; port setup
	banksel ANSELA
	clrf ANSELA
	banksel WPUA
	movlw 0xFF
	movwf WPUA
	banksel LATA
	bcf LATA,portA_pin
	bcf LATA,portA_led
	banksel TRISA
	movlw 0xFF-(1<<portA_pin)-(1<<portA_TX)-(1<<portA_led)
	movwf TRISA
	banksel OPTION_REG
	bcf OPTION_REG,7	; enable pull-ups with WPUx
	banksel 0

	; UART setup (no interrupts!)
	banksel APFCON
	bsf APFCON,7		; RXDTSEL: move UART RX to A5

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
;	bsf RCSTA,4 ; CREN (go!)
	banksel PIE1
	bcf PIE1,5	; without intrr

	; I2C setup
	banksel SSP1ADD
	movlw 0x9F		; set to 50kHz @ 32MHz   (InstClk / (value+1))
	movwf SSP1ADD
	banksel SSP1CON1
	movlw 0xC0   ;
	movwf SSP1STAT
	movlw 0x00   ;
	movwf SSP1CON2
	movlw 0x60   ; SSP mode to I2C Master, want int on start/stop conditions
	movwf SSP1CON3
	movlw 0x28   ; SSP mode to I2C Master, SSPEN
	movwf SSP1CON1


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


	; startup-pause
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


	; Vars setup
	banksel 0
	clrf l_bufTXin
	clrf l_bufTXout
	clrf l_bufRXin
	clrf l_bufRXout
	clrf ml_txCount
	clrf ml_timeCount
	clrf l_TempValid
	clrf l_secondsL
	clrf l_secondsH
	clrf l_nextMeasure

	; pre-loop
	banksel 0
	movlw 0x0A
	call putTX
	movlw 0x0D
	call putTX
	movlw 'G'
	call putTX
	movlw 'o'
	call putTX
	movlw 0x0A
	call putTX
	movlw 0x0D
	call putTX

mainloop:
	banksel 0

	; timer tick
	banksel 0
	btfss PIR1,1		; TMR2IF
	bra $+3
	bcf PIR1,1		; TMR2IF
	incf ml_timeCount,1

	; check/increment l_seconds
	banksel 0
	movlw 0x32
	subwf ml_timeCount,0
	btfsc STATUS,C
	movwf ml_timeCount
	btfsc STATUS,C
	incf l_secondsH,1
	; calc 5.125*timecount
	lslf ml_timeCount,0
	lslf WREG,0
	addwf ml_timeCount,0
	movwf l_secondsL
	lsrf ml_timeCount,0
	lsrf WREG,0
	lsrf WREG,0
	addwf l_secondsL,1

	; alive-LED
	movf l_secondsL,0
	movwf ml_temp
	banksel TRISA
	movf TRISA,0
	bcf WREG,portA_led
	btfsc ml_temp,7
	bsf WREG,portA_led
	movwf TRISA
	banksel 0

	; check to call I2C temperature. Once a second.
	movf l_nextMeasure,0
	subwf l_secondsH,0
	btfss STATUS,Z
	bra $+3
	incf l_nextMeasure,1
	call doI2C_call_and_output

	banksel 0

	nop

	call testTX
;	call testRX

;	call getRX
;	btfss ml_temp,0
;	bra noRX
;	movwf ml_temp3
;	call putTX
;	movlw 0x0D
;	subwf ml_temp3,0
;	btfss STATUS,Z
;	bra noRX
;	movlw 0x0A
;	call putTX
;noRX:
	nop

	call calcPattern

	banksel 0

	call sendLEDstrip

	nop
	bra mainloop


doI2C_call_and_output:
	clrf l_TempValid
	clrw
	call I2C_IO
	movf WREG,0
	btfss STATUS,Z
	bra doI2C_TempA_done
	banksel 0
	movf ml_temp,0
	movwf l_TempAl
	movf ml_temp2,0
	movwf l_TempAh
	bsf l_TempValid,0
doI2C_TempA_done:
	movlw 0x01
	call I2C_IO
	movf WREG,0
	btfss STATUS,Z
	bra doI2C_TempB_done
	banksel 0
	movf ml_temp,0
	movwf l_TempBl
	movf ml_temp2,0
	movwf l_TempBh
	bsf l_TempValid,1
doI2C_TempB_done:



	movlw 'T'
	call putTX
	movlw 'e'
	call putTX
	movlw 'm'
	call putTX
	movlw 'p'
	call putTX
	movlw ':'
	call putTX
	movlw ' '
	call putTX
	banksel 0
	btfss l_TempValid,0
	bra $+7
	movf l_TempAl,0
	movwf l_Al
	movf l_TempAh,0
	movwf l_Ah
	call putDecimalTemp
	bra $+5
	movlw 'E'
	call putTX
	movlw 'r'
	call putTX

	movlw ' '
	call putTX

	banksel 0
	btfss l_TempValid,1
	bra $+7
	movf l_TempBl,0
	movwf l_Al
	movf l_TempBh,0
	movwf l_Ah
	call putDecimalTemp
	bra $+5
	movlw 'E'
	call putTX
	movlw 'r'
	call putTX

;	movlw ' '
;	call putTX
;	banksel 0
;	incf l_TempC,1
;	movf l_TempC,0
;	call putDecimalTemp
;
	movlw 0x0A
	call putTX
	movlw 0x0D
	call putTX

	return


putDecimalTemp:
	banksel 0

	; test sign
	btfss l_Ah,7
	bra noNeg
	movlw '-'
	call putTX
	banksel 0
	clrf ml_temp	; negate l_A
	movf l_Al,0
	sublw 0
	movwf l_Al
	movf l_Ah,0
	subwfb ml_temp,0
	movwf l_Ah
	bra $+3
noNeg:
	movlw ' '
	call putTX
	banksel 0
	; shift integer part into one byte
	lslf l_Al,0
	movwf ml_temp
	rlf l_Ah,0
	lslf ml_temp,1
	rlf WREG,0
	lslf ml_temp,1
	rlf WREG,0
	lslf ml_temp,1
	rlf WREG,0
	movwf ml_temp3
	call div_by_10
	addlw '0'
	movwf ml_temp2
	movf ml_temp,0
	addlw '0'
	movwf ml_temp3
	movf ml_temp2,0
	call putTX
	movf ml_temp3,0
	call putTX
	movlw '.'
	call putTX
	banksel 0
	; after-comma
	; take low-bits *20,div16   or:  *5 , div4
	movlw 0x0F
	andwf l_Al,0
	movwf ml_temp3
	lslf WREG,0
	lslf WREG,0
	addwf ml_temp3,1
	lsrf ml_temp3,1
	lsrf ml_temp3,1
	; digit
	lsrf ml_temp3,0
	addlw '0'
	call putTX
	movlw '0'
	btfsc ml_temp3,0
	movlw '5'
	call putTX
	return

;====================================================================

#include "I2Ccode.asm"

;====================================================================

#include "LEDstrip.asm"

;====================================================================
; UART <=> Ringbuffer stuff.
;====================================================================

#include "uartBuffer.asm"

;===================
putHEX:
	movwf ml_temp2
	lsrf WREG,1
	lsrf WREG,1
	lsrf WREG,1
	lsrf WREG,1
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
	retlw 0

;====================================================================
; math stuff.
;====================================================================

#include "mathFuncs.asm"

;====================================================================
; Color patterns
#include "colorful.asm"

;====================================================================

	org 0x800

#include "mathTables.asm"



	end
