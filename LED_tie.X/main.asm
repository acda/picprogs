


; PIC12F1840 Configuration Bit Settings
#include "p12F1840.inc"


;config bits: internal osc.
; CONFIG1
; __config 0x2FA4
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_ON & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_ON
; CONFIG2
; __config 0x1FFF
 __CONFIG _CONFIG2, _WRT_OFF & _PLLEN_ON & _STVREN_ON & _BORV_LO & _LVP_OFF


NUM_LEDS = .15	; max 0x60!!!

ANIMS_NUMBER = .5
BUTTON_TM_THRES = .100

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
ml_stackptr      = 0x7C

; vars bound to bank 0
l_Al             = 0x20
l_Ah             = 0x21
l_Bl             = 0x22
l_Bh             = 0x23
l_Cl             = 0x24
l_Ch             = 0x25
l_Dl             = 0x26
l_Dh             = 0x27

l_button         = 0x28
l_anim_no        = 0x29

l_secondsL       = 0x2A
l_secondsH       = 0x2B
l_nextMeasure    = 0x2C	; compared against l_secondsH

l_state          = 0x30 ; 0x10 bytes.

l_colR         = 0x40
l_colG         = 0x41
l_colB         = 0x42
l_colH         = 0x43
l_colS         = 0x44
l_colV         = 0x45
l_pos          = 0x47
l_X            = 0x48

l_scratch  = 0x49	; 0x17 bytes



; PIC 12F1840
portA_TX = 0
;portA_I2Cc = 1
;portA_I2Cd = 2
portA_alive = 2
portA_button = 3
portA_pin = 4

bufferLED = 0x2040		; size 3*NUM_LEDS, max 0x90 or 0x30 LEDs (=48d)

stackarea = 0x20F0      ; downward. must be area so low-byte does not wrap.

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
	bcf LATA,portA_alive
	banksel TRISA
	movlw 0xFF-(1<<portA_pin)-(1<<portA_TX)-(1<<portA_alive)
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
	movlw low stackarea
	movwf ml_stackptr
	clrf ml_txCount
	clrf ml_timeCount
	clrf l_secondsL
	clrf l_secondsH
	clrf l_nextMeasure

	call clr_state

	movlw 0xFF
	movwf l_button
	clrf l_anim_no


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
	bcf WREG,portA_alive
	btfsc ml_temp,7
	bsf WREG,portA_alive
	movwf TRISA
	banksel 0




	nop

	call call_anim

	banksel 0

	call sendLEDstrip

	; poll button
	btfsc PORTA,portA_button
	bra _main__buttPrs
	; is up. increase state, cap at 0xFF
	incf l_button,1
	btfsc STATUS,Z
	decf l_button,1
	bra _main__buttDone
_main__buttPrs:
	movlw BUTTON_TM_THRES
	subwf l_button,0
	clrf l_button
	btfss STATUS,C
	bra _main__buttDone
	; change active animation
	incf l_anim_no,1
	movlw ANIMS_NUMBER
	subwf l_anim_no,0
	btfsc STATUS,C
	clrf l_anim_no
	call clr_state

_main__buttDone:


	nop
	bra mainloop

clr_state:
	clrf l_state+0x00
	clrf l_state+0x01
	clrf l_state+0x02
	clrf l_state+0x03
	clrf l_state+0x04
	clrf l_state+0x05
	clrf l_state+0x06
	clrf l_state+0x07
	clrf l_state+0x08
	clrf l_state+0x09
	clrf l_state+0x0A
	clrf l_state+0x0B
	clrf l_state+0x0C
	clrf l_state+0x0D
	clrf l_state+0x0E
	clrf l_state+0x0F
	return

call_anim:
	lslf l_anim_no,0
	andlw 0x0E
	brw
	call gen_pattern1
	return
	call gen_pattern2
	return
	call gen_pattern3
	return
	call gen_pattern4
	return
	call gen_pattern5
	return
	call gen_pattern5
	return
	call gen_pattern5
	return
	call gen_pattern5
	return


;====================================================================

#include "LEDstrip.asm"

;====================================================================

; stack (uses FSR0 and  ml_temp)
start_stack:
	movlw high stackarea
	movwf FSR0H
	movf ml_stackptr,0
	movwf FSR0L
	return

done_stack:
	movf FSR0L,0
	movwf ml_stackptr
	return

push_stack:
	movwi --FSR0
	return

pop_stack:
	moviw FSR0++
	return

;====================================================================
; math stuff.
;====================================================================

#include "../shared/mathFuncs.asm"

;====================================================================

	; pattern generators
#include "pattern1.asm"
#include "pattern2.asm"
#include "pattern3.asm"
;#include "pattern4.asm"
;#include "pattern5.asm"

#include "colorful.asm"

;====================================================================

	org 0x800

#include "../shared/mathTables.asm"



	end
