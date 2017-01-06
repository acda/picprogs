

NUM_PWM_PINS = 0x0A

prepareAndSendServoPWM:
	; multiply and place in PWMdata buffer
	movlw low l_servoValuesBuffer
	movwf FSR0L
	movlw high l_servoValuesBuffer
	movwf FSR0H
	movlw low l_servoPWMdata
	movwf FSR1L
	movlw high l_servoPWMdata
	movwf FSR1H


	moviw 1[FSR0]
	movf WREG,0
	btfss STATUS,Z
	bra $+4
	nop
	nop
	nop


	; copy values and multiply them to rescale to clock-cycles.
	clrf l_Bl
_pSPcopy:
	moviw FSR0++
	movwf l_Al
	moviw FSR0++
	movwf l_Ah
	call mul8000_div2048
	movf l_Bl,0
	movwi FSR1++
	movf l_Al,0
	movwi FSR1++
	movf l_Ah,0
	movwi FSR1++
	incf l_Bl,1
	movlw NUM_PWM_PINS
	subwf l_Bl,0
	btfss STATUS,C
	bra _pSPcopy

	; sort

_pSPsort0:
	movlw low l_servoPWMdata
	movwf FSR0L
	movlw high l_servoPWMdata
	movwf FSR0H
	clrf l_Bl
	clrf l_Bh
_pSPsort:
	moviw 4[FSR0]
	movwf ml_temp
	moviw 5[FSR0]
	movwf ml_temp2
	moviw 1[FSR0]
	subwf ml_temp,0
	moviw 2[FSR0]
	subwfb ml_temp2,0
	btfsc STATUS,C
	bra _pSPsort_nswp
	moviw 3[FSR0]
	movwf ml_temp3
	moviw 0[FSR0]
	movwi 3[FSR0]
	moviw 1[FSR0]
	movwi 4[FSR0]
	moviw 2[FSR0]
	movwi 5[FSR0]
	movf ml_temp3,0
	movwi 0[FSR0]
	movf ml_temp,0
	movwi 1[FSR0]
	movf ml_temp2,0
	movwi 2[FSR0]
	incf l_Bh,1
_pSPsort_nswp:
	addfsr FSR0,3
	incf l_Bl,1
	movlw NUM_PWM_PINS-1
	subwf l_Bl,0
	btfss STATUS,C
	bra _pSPsort
	movf l_Bh,0
	btfss STATUS,Z
	bra _pSPsort0




	; output loop. send-to-pins

	movlw low l_servoPWMdata
	movwf FSR0L
	movlw high l_servoPWMdata
	movwf FSR0H
	clrf l_Bl
_pSP_up:
	moviw 0[FSR0]
	call servoPinUp
	movlw 0x40-.23
	movwf l_Al
	clrf l_Ah
	call delay_Alh
	addfsr FSR0,3
	incf l_Bl,1
	movlw NUM_PWM_PINS
	subwf l_Bl,0
	btfss STATUS,C
	bra _pSP_up

	movlw low (.8000-.54-.66)
	movwf l_Al
	movlw high (.8000-.54-.66)
	movwf l_Ah
	; 66 clks after  call servoPinUp
	call delay_Alh


	; .26+.64-.36=.54  clocks before  call servoPinDown (if value=0)
	movlw low l_servoPWMdata
	movwf FSR0L
	movlw high l_servoPWMdata
	movwf FSR0H
	clrf l_Bl
	movlw 0x0
	movwf ml_temp
	movlw 0x0
	movwf ml_temp2
_pSP_down:
	moviw 1[FSR0]
	movwf l_Al
	moviw 2[FSR0]
	movwf l_Ah
	movf ml_temp,0
	subwf l_Al,1
	movf ml_temp2,0
	subwfb l_Ah,1
	moviw 1[FSR0]
	movwf ml_temp
	moviw 2[FSR0]
	movwf ml_temp2
	movlw .64-.36
	addwf l_Al,1
	movlw .0
	addwfc l_Ah,1
	call delay_Alh
	moviw 0[FSR0]
	call servoPinDown
	addfsr FSR0,3
	incf l_Bl,1
	movlw NUM_PWM_PINS
	subwf l_Bl,0
	btfss STATUS,C
	bra _pSP_down



	return




mul8000_div2048:
	; calc *125 /32  for value in l_A*
	; 3*A -> temp
	lslf l_Al,0
	movwf ml_temp
	rlf l_Ah,0
	movwf ml_temp2
	movf l_Al,0
	addwf ml_temp,1
	movf l_Ah,0
	addwfc ml_temp2,1
	; A<<7
	clrf ml_temp3
	lsrf l_Ah,1
	rrf l_Al,1
	rrf ml_temp3,1
	; sub temp from A.
	movf ml_temp,0
	subwf ml_temp3,1
	movf ml_temp2,0
	subwfb l_Al,1
	clrf WREG
	subwfb l_Ah,1
	; now have *125. do >>5
	lslf ml_temp3,1
	rlf l_Al,1
	rlf l_Ah,1
	lslf ml_temp3,1
	rlf l_Al,1
	rlf l_Ah,1
	lslf ml_temp3,1
	rlf l_Al,1
	rlf l_Ah,1
	return



servoPinUp:
	; clocks 12
	banksel LATA
	andlw 0x0F
	lslf WREG,0
	lslf WREG,0
	brw
	bsf LATS1,portbit_S1
	banksel 0
	return
	nop
	bsf LATS2,portbit_S2
	banksel 0
	return
	nop
	bsf LATS3,portbit_S3
	banksel 0
	return
	nop
	bsf LATS4,portbit_S4
	banksel 0
	return
	nop
	bsf LATS5,portbit_S5
	banksel 0
	return
	nop
	bsf LATS6,portbit_S6
	banksel 0
	return
	nop
	bsf LATS7,portbit_S7
	banksel 0
	return
	nop
	bsf LATS8,portbit_S8
	banksel 0
	return
	nop
	bsf LATS9,portbit_S9
	banksel 0
	return
	nop
	bsf LATS10,portbit_S10
	banksel 0
	return
	nop
	bsf LATS11,portbit_S11
	banksel 0
	return
	nop
	bsf LATS12,portbit_S12
	banksel 0
	return
	nop
	bsf LATS13,portbit_S13
	banksel 0
	return
	nop
	bsf LATS14,portbit_S14
	banksel 0
	return
	nop
	bsf LATS15,portbit_S15
	banksel 0
	return
	nop
	bsf LATS16,portbit_S16
	banksel 0
	return
	nop

servoPinDown:
	; clocks 12
	banksel LATA
	andlw 0x0F
	lslf WREG,0
	lslf WREG,0
	brw
	bcf LATS1,portbit_S1
	banksel 0
	return
	nop
	bcf LATS2,portbit_S2
	banksel 0
	return
	nop
	bcf LATS3,portbit_S3
	banksel 0
	return
	nop
	bcf LATS4,portbit_S4
	banksel 0
	return
	nop
	bcf LATS5,portbit_S5
	banksel 0
	return
	nop
	bcf LATS6,portbit_S6
	banksel 0
	return
	nop
	bcf LATS7,portbit_S7
	banksel 0
	return
	nop
	bcf LATS8,portbit_S8
	banksel 0
	return
	nop
	bcf LATS9,portbit_S9
	banksel 0
	return
	nop
	bcf LATS10,portbit_S10
	banksel 0
	return
	nop
	bcf LATS11,portbit_S11
	banksel 0
	return
	nop
	bcf LATS12,portbit_S12
	banksel 0
	return
	nop
	bcf LATS13,portbit_S13
	banksel 0
	return
	nop
	bcf LATS14,portbit_S14
	banksel 0
	return
	nop
	bcf LATS15,portbit_S15
	banksel 0
	return
	nop
	bcf LATS16,portbit_S16
	banksel 0
	return
	nop
