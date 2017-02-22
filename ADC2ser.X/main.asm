#include "p12F1840.inc"

; PIC program which reads three analog inputs cyclically,
; and outputs 4-digit hex values as ascii
; on serial 50 times per second.


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

l_bufRXin    = 0x24
l_bufRXout   = 0x25
l_bufTXin    = 0x26
l_bufTXout   = 0x27

l_ADC_num    = 0x28

l_conv_result = 0x30	; several... reserve up to 0x50


bufferRX      = 0xA0
bufferRXend   = 0xC8
bufferTX      = 0xC8
bufferTXend   = 0xF0


portA_uart_tx = 0	; same as ICSP-dat
portA_analog_a = 1
portA_analog_b = 2
portA_analog_c = 4
portA_led = 5

ADC_chan_analog_a = 1
ADC_chan_analog_b = 2
ADC_chan_analog_c = 3


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
	movlw (1<<portA_analog_a) | (1<<portA_analog_b) | (1<<portA_analog_c)
	movwf ANSELA
	banksel WPUA
	movlw (1<<portA_analog_a) | (1<<portA_analog_b) | (1<<portA_analog_c)
	xorlw 0xFF
	movwf WPUA
	banksel LATA
	bcf LATA,portA_led
	banksel TRISA
	movlw 0xFF-(1<<portA_uart_tx)
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



	; UART BAUD rate setup.
	; formula for baudrate value:
	;  32e6/(4*115200)-1     for 115k2 rate  =  68.44
	banksel BAUDCON
	movlw 0x48
	movwf BAUDCON		; RCIDL (BRG16=1)
	banksel TXSTA
	bcf TXSTA,4	; SYNC
	bsf TXSTA,2 ; BRGH
	; Set to 100.0 kBaud.
	banksel SPBRGL
	movlw .68      ;  for 115k2baud, .68
	movwf SPBRGL
	movlw 0x00
	movwf SPBRGH

	; UART TX
	banksel BAUDCON
	banksel TXSTA
	bsf TXSTA,5	; TXEN (go)
	banksel RCSTA
	bsf RCSTA,7	; SPEN




	; enable ADC
	banksel ADCON0
	movlw (ADC_chan_analog_a<<2)	; choose channel
	movwf ADCON0
	movlw 0x63	; left(high)-justify, slow conversion (2us), internal VRef
	movlw 0x60	; left(high)-justify, slow conversion (2us), Vdd as ref
	movwf ADCON1
	bsf ADCON0,0	; ADON  - enable ADC module.
	; and start it to prevent reading one bogus value.
	nop
	nop
	bsf ADCON0,1	; GO/~DONE bit
	banksel 0


	clrf ml_timeCount
	clrf l_secondsL
	clrf l_secondsH

	clrf l_ADC_num

	clrf l_bufRXin
	clrf l_bufRXout
	clrf l_bufTXin
	clrf l_bufTXout

	movlw .13
	call putTX
	movlw .10
	call putTX
	movlw .10
	call putTX
	movlw 'A'
	call putTX
	movlw 'D'
	call putTX
	movlw 'C'
	call putTX
	movlw .13
	call putTX
	movlw .10
	call putTX


mainloop:
	; timer ?
	banksel 0
	btfss PIR1,1
	bra noTmr
	bcf PIR1,1
	incf ml_timeCount,1
	movlw 0x32	; 50
	subwf ml_timeCount,0
	btfss STATUS,C
	bra noSecondTick
	clrf ml_timeCount
	incf l_secondsH,1


;	movf l_secondsH,0
;	call getHexDigit
;	call putTX
;	movlw ' '
;	call putTX

noSecondTick:
	; output analog inputs 50 times per second.
 	call put_all_to_TX
noTmr:
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

	; 1ms is 8000 cycles.


	; alive-LED
	banksel TRISA
	movlw 0x19
	subwf ml_timeCount,0
	btfss STATUS,C
	bra $+4
	nop
	bcf TRISA,portA_led
	bra $+2
	bsf TRISA,portA_led

	banksel 0

	; query ADC.
	banksel ADCON0
	btfsc ADCON0,1	; GO/~DONE bit
	bra _ADC_is_running
	; pick up value
	movf ADRESL,0
	movwf ml_temp
	movf ADRESH,0
	movwf ml_temp2
	banksel 0

	; put value in values buffer
	movlw low l_conv_result
	movwf FSR0L
	movlw high l_conv_result
	movwf FSR0H
	lslf l_ADC_num,0
	addwf FSR0L,1
	btfsc STATUS,C
	incf FSR0H,1
	movf ml_temp,0
	movwi 0[FSR0]
	movf ml_temp2,0
	movwi 1[FSR0]

	; move to next input
	call ADC_to_next
	; ADC holding-cell charging time
	movlw .20
	movwf ml_temp
	decfsz ml_temp,1
	bra $-1

	; start ADC
	banksel ADCON0
	bsf ADCON0,1	; GO/~DONE bit
	banksel 0



_ADC_is_running:
	banksel 0

	; Uart in polled mode
	call testTX

	bra mainloop


ADC_to_next:
	banksel 0
	movf l_ADC_num,0
	andlw 3
	brw
	bra ADC_to_nr1
	bra ADC_to_nr2
	bra ADC_to_nr0
	bra ADC_to_nr0
ADC_to_nr0:
	movlw 0
	movwf l_ADC_num
	movlw ADC_chan_analog_a
	bra ADC_to
ADC_to_nr1:
	movlw 1
	movwf l_ADC_num
	movlw ADC_chan_analog_b
	bra ADC_to
ADC_to_nr2:
	movlw 2
	movwf l_ADC_num
	movlw ADC_chan_analog_c
	bra ADC_to
ADC_to:
	lslf WREG,0
	lslf WREG,0
	bsf WREG,0	; add ADON bit
	banksel ADCON0
	movwf ADCON0
	banksel 0
	return


put_all_to_TX:
	banksel 0
	movlw low l_conv_result
	movwf FSR1L
	movlw high l_conv_result
	movwf FSR1H
	movlw .3
	movwf ml_temp2
	bra $+3
_put_all_loop:
	movlw ' '
	call putTX
	moviw 1[FSR1]
	lsrf WREG,0
	lsrf WREG,0
	lsrf WREG,0
	lsrf WREG,0
	call getHexDigit
	call putTX
	moviw 1[FSR1]
	call getHexDigit
	call putTX
	moviw 0[FSR1]
	lsrf WREG,0
	lsrf WREG,0
	lsrf WREG,0
	lsrf WREG,0
	call getHexDigit
	call putTX
	moviw 0[FSR1]
	call getHexDigit
	call putTX
	addfsr FSR1,2
	decfsz ml_temp2,1
	bra _put_all_loop
	movlw .13
	call putTX
	movlw .10
	call putTX
	return



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


getHexDigit:
	andlw 0x0F
	brw
	retlw '0'
	retlw '1'
	retlw '2'
	retlw '3'
	retlw '4'
	retlw '5'
	retlw '6'
	retlw '7'
	retlw '8'
	retlw '9'
	retlw 'A'
	retlw 'B'
	retlw 'C'
	retlw 'D'
	retlw 'E'
	retlw 'F'
	retlw 'F'


#include "uartBuffer.asm"

	end


