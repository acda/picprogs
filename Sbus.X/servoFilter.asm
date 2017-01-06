

;l_flippinC
;l_flippinT

FLIP_THRES_LOW  = 0x0333
FLIP_THRES_HIGH = 0x04CD

NUM_MODES = 5

filterServoValues:
	banksel 0
	; check lost signal ("fail-safe")
	movf l_signalLost,0
	btfss STATUS,Z
	bra _flipSigLost

	; check if initial state
	movf l_filterFirst,0
	btfsc STATUS,Z
	bra $+.10
	clrf l_flippinC
	movlw 0xFF
	movwf l_flippinT
	decf l_filterFirst,1
	banksel l_servoValuesBuffer
	movf l_servoValuesBuffer+.9,0
	banksel 0
	btfsc WREG,2
	bsf l_flippinC,0


	btfsc l_flippinC,0
	bra _flipon1	; was on 1
	; was on 0
	banksel l_servoValuesBuffer
	movlw low FLIP_THRES_HIGH
	subwf l_servoValuesBuffer+.8,0
	movlw high FLIP_THRES_HIGH
	subwfb l_servoValuesBuffer+.9,0
	banksel 0
	btfss STATUS,C
	bra _flipNoFlip
	; flipped from 0 to 1
	clrf l_flippinT
	movlw 1
	iorwf l_flippinC,1
	movlw 2
	addwf l_flippinC,1
	bra _flipDne
_flipon1:
	banksel l_servoValuesBuffer
	movlw low FLIP_THRES_LOW
	subwf l_servoValuesBuffer+.8,0
	movlw high FLIP_THRES_LOW
	subwfb l_servoValuesBuffer+.9,0
	banksel 0
	btfsc STATUS,C
	bra _flipNoFlip
	; flipped from 1 to 0
	clrf l_flippinT
	movlw 0xFE
	andwf l_flippinC,1
	movlw 2
	addwf l_flippinC,1
	bra _flipDne
_flipNoFlip:
	incfsz l_flippinT,0
	incf l_flippinT,1
	movlw .25
	subwf l_flippinT,0
	btfss STATUS,Z
	bra _flipDne
	; timeout. no flips for some time.

	movlw 2*NUM_MODES+2+2
	subwf l_flippinC,0
	btfsc STATUS,C
	bra $+5
	lsrf l_flippinC,0
	addlw 0xFE
	btfsc STATUS,C
	movwf l_modeSwitch
	movlw 1
	andwf l_flippinC,1
	bra _flipDne

_flipSigLost:
	clrf l_flippinC
	clrf l_flippinT
	movlw 1
	movwf l_modeSwitch
	movlw .10
	movwf l_filterFirst


_flipDne:
	lslf l_modeSwitch,0
	addwf l_modeSwitch,0
	addlw 2
	andlw .15
	banksel l_servoValuesBuffer
	clrf l_servoValuesBuffer+.12
	movwf l_servoValuesBuffer+.13
	lsrf l_servoValuesBuffer+.13,1
	rrf l_servoValuesBuffer+.12,1

	movlw 0xFF
	movwf l_servoValuesBuffer+.14
	movwf l_servoValuesBuffer+.16
	movwf l_servoValuesBuffer+.18
	movwf l_servoValuesBuffer+.20
	movwf l_servoValuesBuffer+.22
	movlw 0x03
	movwf l_servoValuesBuffer+.15
	movwf l_servoValuesBuffer+.17
	movwf l_servoValuesBuffer+.19
	movwf l_servoValuesBuffer+.21
	movwf l_servoValuesBuffer+.23


	banksel 0


	return



