#!/usr/bin/env python2
import sys
import time


state = [0]*15
LED = [(0,0,0)]*15

sta = 0   # 192..255: dropping type (sta>>4), pos=(sta&15)
          # 0 uninit.
          # 64..127   pause next.

while True:
	if sta==0:
		for i in range(15):
			LED[i] = (0,0,0)
		sta=128-50
	if sta<128:
		sta+=1
		continue
