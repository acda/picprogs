; PIC12F1840 Configuration Bit Settings
#include "p12F1840.inc"


;config bits: internal osc.
; CONFIG1
; __config 0x2FE4
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_ON
; CONFIG2
; __config 0x1FFF
 __CONFIG _CONFIG2, _WRT_OFF & _PLLEN_ON & _STVREN_ON & _BORV_LO & _LVP_OFF



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

l_cntLin         = 0x3E

l_bufTXin       = 0x40
l_bufTXout      = 0x41
l_bufRXin       = 0x42
l_bufRXout      = 0x43

l_scratch  = 0x44	; 8 bytes



; PIC 12F1840
portA_TX = 0
portA_pin = 4
portA_led = 5
portA_RX = 1


bufferTX = 0x20C0
bufferTXend = 0x20E8
bufferRX = 0x20E8
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
	bcf LATA,portA_led
	banksel TRISA
	movlw 0xFF-(1<<portA_TX)-(1<<portA_led)
	movwf TRISA
	banksel OPTION_REG
	bcf OPTION_REG,7	; enable pull-ups with WPUx
	banksel 0

	; UART setup (no interrupts!)
	banksel APFCON
	bcf APFCON,7		; RXDTSEL: keep UART RX on A1

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


	; setup timer 1 as gated pulse-width receiver.
	banksel 0	; tmr1 regs are in bank #0
	movlw 0xD0		; gated, highactive, notogg, single, t1gate-pin
	movwf T1GCON
	movlw 0x31 ; inst-clk, 8:1, enable     0x51		; sysClk, 1:2, enable
	movwf T1CON
	movlw 0xD0
	movwf T1GCON
	; clear int
	banksel PIE1
	bcf PIE1,0	;TMR1IE
	bcf PIE1,7	;TMR1GIE
	banksel 0
	bcf PIR1,7	; TMR1GIF
	; and start
	clrf TMR1L
	clrf TMR1H
	bsf T1GCON,3	;T1GGO



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
	movlw 'H'
	call putTX
	movlw 'e'
	call putTX
	movlw 'l'
	call putTX
	movlw 'l'
	call putTX
	movlw 'o'
	call putTX
	movlw ' '
	call putTX
	movlw 'W'
	call putTX
	movlw 'o'
	call putTX
	movlw 'r'
	call putTX
	movlw 'l'
	call putTX
	movlw 'd'
	call putTX
	movlw '!'
	call putTX
	movlw 0x0D
	call putTX
	movlw 0x0A
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

	; body

	banksel 0

	nop

	call testTX
;	call testRX


	call pollT1G


	banksel 0

	nop
	bra mainloop

pollT1G:
	banksel 0
	btfss PIR1,7	;TMR1GIF
	return
	bcf PIR1,7
	; pick up value from TMR1 L/H
	; scale so 0.5ms is 0, 2.5ms is 1024. with 16MHz counting, 0.5ms is 8000, 2.5ms is 40000.
	; scale so 0.5ms is 0, 2.5ms is 1024. with  8MHz counting, 0.5ms is 4000, 2.5ms is 20000.
	; todo: overflow check with T1IF?
	movf TMR1L,0	; TMR1 is in bank0
	movwf l_Al
	movf TMR1H,0
	movwf l_Ah
;	; multiply with 2097
;	movlw 0x97
;	movwf l_Bl
;	movlw 0x08
;	movwf l_Bh
	; multiply with 8389
	movlw 0xC5
	movwf l_Bl
	movlw 0x20
	movwf l_Bh
	movlw l_Cl
	movwf FSR1L	; loads result in Cl:h and Dl:h. high in D.
	clrf FSR1H
;	call multiply_16_16_32	; mul Ah:Al * Bh:Bl -> [FSR1]
;	; now result is almost in Dl:Dh. 1.5ms will yield 24000 -> Dl:h=0x300.
;	; subtract 0x100 and clamp range
;	movlw 1
;	subwf l_Dh,1
;	btfsc STATUS,C
;	bra $+3
;	clrf l_Dl	; underflow. clamp to zero
;	clrf l_Dh
;	movlw 4
;	subwf l_Dh,0
;	btfss STATUS,C
;	bra $+5
;	movlw 0xFF
;	movwf l_Dl	; overflow. clamp to 0x3FF
;	movlw 0x03
;	movwf l_Dh

	; let timer run again
	bcf T1CON,0
	movlw 0
	movwf TMR1L
	movwf TMR1H
	bsf T1CON,0
	bsf T1GCON,3	;T1GGO


	incf l_cntLin,1
	movf l_cntLin,0
	andlw 0x07
	btfss STATUS,Z
	return


;	movf l_Dh,0
;	call putTX_hex
	movf l_Ah,0
	call putTX_hex
	movf l_Al,0
	call putTX_hex
	movlw ' '
	call putTX

	movf l_cntLin,0
	andlw 0x03F
	btfss STATUS,Z
	bra $+5
	movlw 0x0D
	call putTX
	movlw 0x0A
	call putTX

	return

putTX_hex:
	movwf ml_temp2
	lsrf W,0
	lsrf W,0
	lsrf W,0
	lsrf W,0
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
; UART <=> Ringbuffer stuff.
;====================================================================

#include "uartBuffer.asm"

;====================================================================
; math stuff.
;====================================================================

#include "mathFuncs.asm"

;====================================================================
;	org 0x800
;
#include "mathTables.asm"
;


	end
