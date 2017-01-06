; PIC16F1847 Configuration Bit Settings
#include "p16F1847.inc"


; CONFIG1
; __config 0xEFFC
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_ON & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_ON
; CONFIG2
; __config 0xFEFF
 __CONFIG _CONFIG2, _WRT_OFF & _PLLEN_OFF & _STVREN_ON & _BORV_LO & _LVP_ON


; Pin out
portA_pot_input = 1
adc_pot_input = 1
portB_uart_TX   = 2
portB_led = 3



temp = 0x70
count0 = 0x71
count1 = 0x72
timecount = 0x73


	org 0
	goto skipToSetup

	org 4
	retfie

skipToSetup:
	nop
	; setup low-speed int-osc
	banksel OSCCON
	movlw 0x58
	movwf OSCCON
	banksel 0

	; setup IO pins
	banksel LATA
	movlw 0xFF
	movwf LATA
	movlw 0xFF-(1<<portB_led)
	movwf LATB
	banksel TRISA
	movlw 0xFF
	movwf TRISA
	movlw 0xFF-(1<<portB_uart_TX)
	movwf TRISB
	banksel ANSELA
	movlw (1<<portA_pot_input)
	movwf ANSELA
	clrf ANSELB
	banksel ADCON0
	movlw (adc_pot_input<<2)	; select input, nogo, no enable
	movwf ADCON0
	movlw (3<<4) + 0 + 0x80		; int-osc, right-just, ref=pwr/gnd
	movwf ADCON1
	bsf ADCON0,0		; ADON = 1
	banksel OPTION_REG
	bcf OPTION_REG,7	; enable pull-ups with WPUx
	banksel 0


	clrf timecount
blink:
	incf timecount,1
	banksel TRISB
	movf TRISB,0
	andlw 0xFF-(1<<portB_led)
	btfsc timecount,4
	iorlw (1<<portB_led)
	movwf TRISB

	; delay 7804 cycles
	banksel 0
	movlw 0x0B
	movwf count1
	movlw 0x24
	movwf count0
loop:
	decfsz count0,1
	bra loop
	nop
	nop
	decfsz count1,1
	bra loop


	bra blink



	end

