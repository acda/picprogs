


multiply_8_8_16:
	; mult ml_Al with WREG. Result in WREG/ml_Al, high in ml_Ah
	; max 50
	banksel 0
	movlp high getSquareQuarterLow
	movwf l_Ah
	subwf l_Al,0
	btfss STATUS,C
	sublw 0
	movwf ml_temp	; is diff of inputs
	movf l_Ah,0
	addwf l_Al,1	; is sum of inputs
	btfsc STATUS,C
	bra multIsHigh
	nop
	movf l_Al,0
	call getSquareQuarterHigh
	movwf l_Ah
	movf l_Al,0
	call getSquareQuarterLow
	movwf l_Al
	movf ml_temp,0
	call getSquareQuarterHigh
	movwf ml_temp2
	movf ml_temp,0
	call getSquareQuarterLow
	movlp 0
	; now sub  [ml_Ah:ml_Al] - [ml_temp2,WREG] -> [ml_Ah:ml_Al]
	subwf l_Al,1
	movf ml_temp2,0
	subwfb l_Ah,1
	movf l_Al,0
	return
multIsHigh:
	movf l_Al,0
	call getSquareQuarterHigh2
	movwf l_Ah
	movf l_Al,0
	call getSquareQuarterLow2
	movwf l_Al
	movf ml_temp,0
	call getSquareQuarterHigh
	movwf ml_temp2
	movf ml_temp,0
	call getSquareQuarterLow
	movlp 0
	; now sub  [ml_Ah:ml_Al] - [ml_temp2,WREG] -> [ml_Ah:ml_Al]
	subwf l_Al,1
	movf ml_temp2,0
	subwfb l_Ah,1
	movf l_Al,0
	return



multiply_16_16_32:
	; mult Ah:Al * Bh:Bl -> [FSR1] (low in W). Uses l_scratch + 0..3
	; max 233
	movf l_Ah,0
	movwf l_scratch+1
	movf l_Al,0
	movwf l_scratch+0
	movf l_Bl,0
	call multiply_8_8_16		; mult Al*Bl
	movwi 0[FSR1]
	movf l_Ah,0
	movwf l_scratch+2

	movf l_scratch+1,0
	movwf l_Al
	movf l_Bl,0
	call multiply_8_8_16		; mult Ah*Bl
	addwf l_scratch+2,1
	clrw
	addwfc l_Ah,0
	movwf l_scratch+3

	movf l_scratch+0,0
	movwf l_Al
	movf l_Bh,0
	call multiply_8_8_16		; mult Al*Bh
	addwf l_scratch+2,0
	movwi 1[FSR1]
	movf l_Ah,0
	addwfc l_scratch+3,1

	movf l_scratch+1,0
	movwf l_Al
	movf l_Bh,0
	call multiply_8_8_16		; mult Ah*Bh
	addwf l_scratch+3,0
	movwi 2[FSR1]
	clrw
	addwfc l_Ah,0
	movwi 3[FSR1]

	moviw 0[FSR1]

	return



multiply_8_8_8:
	; mult ml_Al with WREG. Result in WREG
	; max 21
	banksel 0
	movlp high getSquareQuarterLow
	call getSquareQuarterLow
	movwf ml_temp
	movf l_Al,0
	call getSquareQuarterLow
	movlp 0
	addwf ml_temp,0
	return



; math. divide
divide_16_8:
	; div m_A / WREG -> result in WREG, remainder in m_Al
	banksel 0
	movwf ml_temp	; divisor in 16 bits.
	clrf ml_temp2
	movlw 8
	movwf ml_temp3	; counter
	clrf ml_temp4	; for result
divloop16:
	lslf ml_temp4,1	; shift result
	lsrf ml_temp,1	; shift divisor
	rrf ml_temp2,1
	movf ml_temp2,0	; try sub
	subwf l_Al,0
	movf ml_temp,0
	subwfb l_Ah,0
	btfss STATUS,C	; if underflow (borrow), cannot sub. skip.
	bra divNoSub16
	movf ml_temp2,0
	subwf l_Al,1
	movf ml_temp,0
	subwfb l_Ah,1
	bsf ml_temp4,0
divNoSub16:
	decfsz ml_temp3,1
	bra divloop16
	movf ml_temp4,0
	return


div_by_10:
	; Value in WREG, result in WREG, remainder in ml_temp
	movwf ml_temp
	clrf ml_temp2
	movlw 0xA0	; bitpos 4
	subwf ml_temp,0
	btfss STATUS,C
	bra $+3
	movwf ml_temp
	bsf ml_temp2,4
	movlw 0x50	; bitpos 3
	subwf ml_temp,0
	btfss STATUS,C
	bra $+3
	movwf ml_temp
	bsf ml_temp2,3
	movlw 0x28	; bitpos 2
	subwf ml_temp,0
	btfss STATUS,C
	bra $+3
	movwf ml_temp
	bsf ml_temp2,2
	movlw 0x14	; bitpos 1
	subwf ml_temp,0
	btfss STATUS,C
	bra $+3
	movwf ml_temp
	bsf ml_temp2,1
	movlw 0x0A	; bitpos 0
	subwf ml_temp,0
	btfss STATUS,C
	bra $+3
	movwf ml_temp
	bsf ml_temp2,0
	movf ml_temp2,0
	return

