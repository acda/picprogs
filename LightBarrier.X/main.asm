#include "p16F1847.inc"

; Lichtschranke -
; Messung von Unterbrechungen an einer Lichtschranke.
;
; Beschaltung (pin, port, func):
; -  9 B3 CCP1 - PWM Ausgang #1 für Leistung Laserdiode.
; - 16 A7 CCP2*- PWM Ausgang #2.
; -  2 A3 CCP3 - PWM Ausgang #3.
; -  3 A4 CCP4 - PWM Ausgang #4.
; - 17 A0 AN0  - Analog-Eingang #1 zum Messen der Spannung von der Messdiode.
; - 18 A1 AN1  - Analog-Eingang #2
; -  1 A2 AN2  - Analog-Eingang #3
; -  7 B1 AN11 - Analog-Eingang #4
; -  8 B2 TX   - serielle zum Melden der Treffer.
; - 10 B4 IOC  - Digital-Eingang #1 für Erkennung Treffer.
; - 11 B5 IOC  - Digital-Eingang #2
; - 12 B6 IOC  - Digital-Eingang #3  ( & IOC-prog )
; - 13 B7 IOC  - Digital-Eingang #4  ( & IOC-prog )
; -  6 B0 LED  - keep-alive LED.

; Logik:
;
; Mit PWM hält der controller die Laserdiode so hell, daß der Detektor ein 
; konstanten Pegel ergibt, sicher im Bereich, der als low erkannt wird.
; Dieser Regler ist langsam.
;
; Der Logikeingang sollte davon nichts merken und immer low sehen.
; Eine Unterbrechung wird als high erkannt. Der Controller misst die Länge bis 
; der Eingang wieder high geht und meldet das.
; Während der low-Phase ist die Regelung langsamer.

; Module:
;
; Timer1 ist 16-bit Timer zum pollen der Dauer von Unterbrechungen.
; Timer2 ist ein 100 Tick/second, triggert den langsamen Helligkeitsregler.
; Timer4 ist der Timer für die PWM Module. no prescaler, loop-period 128 or 100.
; IOC-interrupt: Pin-change Erkennung.










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
ml_timeCount     = 0x74     ; used for polled timer2.


l_Al        = 0x20
l_Ah        = 0x21

l_secondsL   = 0x22
l_secondsH   = 0x23

l_ANpolling = 0x24
l_lastPortB = 0x25

l_statbuff  = 0xA0  ; 8 per input. don't need, but to have them...


portB_PWM1 = 3
portA_PWM2 = 7
portA_PWM3 = 3
portA_PWM4 = 4
portA_analog1 = 0
portA_analog2 = 1
portA_analog3 = 2
portB_analog4 = 1
portB_sense1 = 4
portB_sense2 = 5
portB_sense3 = 6
portB_sense4 = 7
portB_serTX = 2
portB_led = 0
analogAN1 = 0
analogAN2 = 1
analogAN3 = 2
analogAN4 = 11


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
	movlw .150
	movwf ml_temp
	nop
	decfsz ml_temp,1
	goto $-2

	; port setup
	banksel ANSELA
	movlw (1<<portA_analog1)+(1<<portA_analog2)+(1<<portA_analog3)
	movwf ANSELA
	movlw (1<<portB_analog4)
	movwf ANSELB
	banksel WPUA
	movlw 0xFF-((1<<portA_analog1)+(1<<portA_analog2)+(1<<portA_analog3))
	movwf WPUA
	movlw 0xFF-((1<<portB_analog4))
	movwf WPUB
	banksel LATA
	bcf LATB,portB_led
	banksel TRISA
	movlw 0xFF-(portA_PWM2)-(portA_PWM3)-(portA_PWM4)
	movwf TRISA
	movlw 0xFF-(1<<portB_serTX)-(portB_PWM1)
	movwf TRISB
	banksel OPTION_REG
	bcf OPTION_REG,7	; enable pull-ups with WPUx
	banksel 0

	; pin-function select.
	banksel APFCON0
	movf APFCON0,0
	bcf W,0   ; CCP1 to B3
	bsf W,3   ; CCP2 to A7
	movwf APFCON0
	movf APFCON1,0
	bcf W,0   ; TX to B2
	movwf APFCON1

	; UART BAUD rate setup.
	; formula for baudrate value:
	;  32e6/(4*115200)-1
	banksel BAUDCON
	movlw 0x48
	movwf BAUDCON		; RCIDL (BRG16=1)
	banksel TXSTA
	bcf TXSTA,4	; SYNC
	bsf TXSTA,2 ; BRGH
	; Set to 115.2 kBaud. (as good as it gets)
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

	; timer4 for PWM, cycle 128
	banksel TMR4
	movlw 0x7F	; loop 128
	movwf PR4
	movlw 0x04	; no pre/postscale, not yet enable.
	movwf T4CON
	banksel PIE3
	bcf PIE3,1  ; TMR4IE  disable int


	; enable ADC
	banksel ADCON0
	movlw analogAN1*4	; choose channel
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
	movlw #0
	movwf l_ANpolling


	; set up int-on-change.


mainloop:
	; first, poll ADC.

	; query ADC.
	banksel ADCON0
	btfsc ADCON0,1	; GO/~DONE bit
	bra _ADC_still_running
	; pick up value
	movf ADRESL,0
	movwf ml_temp
	movf ADRESH,0
	movwf ml_temp2
	; choose next channel
	incf l_ANpolling,1
	movf l_ANpolling,0
	andlw #3
	brw
	addlw ((4*analogAN1)-0) - ((4*analogAN2)-1)
	addlw ((4*analogAN2)-1) - ((4*analogAN3)-2)
	addlw ((4*analogAN3)-2) - ((4*analogAN4)-3)
	addlw ((4*analogAN4)-3)
	movwf ADCON0
	; start ADC
	bsf ADCON0,1	; GO/~DONE bit
	banksel 0
	goto _ADC_done

_ADC_still_running:
	; did not use time for restart, check regulator.


_ADC_done:   ; when ADC was done, 22 cycles to here.
	banksel 0
	; test input bits. high is laser interrupted.

	; need to-high and a to-low reg.
	; to-high:   newVal & ~oldVal
	; to-low:    ~newVal & oldVal

	movf l_lastPortB,0
	movwf ml_temp ; oldVal
	movf PORTB,0
	movwf l_lastPortB ; newVal
	movwf ml_temp3
	xorlw 0xFF
	movwf ml_temp4
	movf ml_temp ; oldVal
	andwf ml_temp4,1 ; to-low value
	xorlw 0xFF
	andwf ml_temp3,1 ; to-high value

	clrf FSR0H

	; now, test bits.
	btfsc ml_temp3,portB_sense1
	call input1_to_high
	btfsc ml_temp3,portB_sense2
	call input2_to_high
	btfsc ml_temp3,portB_sense3
	call input3_to_high
	btfsc ml_temp3,portB_sense4
	call input4_to_high
	btfsc ml_temp4,portB_sense1
	call input1_to_low
	btfsc ml_temp4,portB_sense2
	call input2_to_low
	btfsc ml_temp4,portB_sense3
	call input3_to_low
	btfsc ml_temp4,portB_sense4
	call input4_to_low



	goto mainloop

input1_to_high:
	movlw l_statbuff + 0*8
	goto generic_to_high
input2_to_high:
	movlw l_statbuff + 1*8
	goto generic_to_high
input3_to_high:
	movlw l_statbuff + 2*8
	goto generic_to_high
input4_to_high:
	movlw l_statbuff + 3*8
	goto generic_to_high
input1_to_low:
	movlw l_statbuff + 0*8
	goto generic_to_low
input2_to_low:
	movlw l_statbuff + 1*8
	goto generic_to_low
input3_to_low:
	movlw l_statbuff + 2*8
	goto generic_to_low
input4_to_low:
	movlw l_statbuff + 3*8
	goto generic_to_low

	; note: TMR1L TMR1H are in bank #0.



generic_to_high:
	; pin to high means the laser was interrupted.
	; store timer and exit.
	movwf FSR0L
	; read timer 1
	movf TMR1H,0
	movwf ml_temp2
	movf TMR1L,0
	movwf ml_temp
	movf TMR1H,0
	subwf ml_temp2,0
	btfsc STATUS,Z
	goto $+3
	movf TMR1L,0
	movwf ml_temp
	movf ml_temp,0
	movwi 0[FSR0]
	movf ml_temp2,0
	movwi 1[FSR0]
	return



generic_to_low:
	; pin to low means the laser is no longer interrupted. Take the time.
	movwf FSR0L
	; read timer 1
	movf TMR1H,0
	movwf ml_temp2
	movf TMR1L,0
	movwf ml_temp
	movf TMR1H,0
	subwf ml_temp2,0
	btfss STATUS,Z
	incf ml_temp2,1
	; sub   new - old
	moviw 0[FSR0]
	subwf ml_temp,0
	movwf ml_temp
	moviw 1[FSR0]
	subwfb ml_temp2,0
	movwf ml_temp2
	; need to send this on serial.

	nop
	movlw #0
	;call put_TX
	lsrf FSR0L,0
	lsrf WREG,0
	lsrf WREG,0
	;call put_TX
	movf ml_temp,0
	;call put_TX
	movf ml_temp2,0
	;call put_TX

	return

	end


