#!/usr/bin/env python

# program to try out the servo-over-sbus controlling

# format of sbus:


import math
import serial
import sys
import threading
import time


baudrate = 115200
serport = '/dev/ttyUSB0'


ser = None

def main(args):

	global ser
	global values

	ser = serial.Serial(serport,baudrate,timeout=0,parity=serial.PARITY_NONE,stopbits=serial.STOPBITS_ONE,bytesize=8,rtscts=False,xonxoff=False)

	print "sending to %s" % serport

	thread = threading.Thread(target=readloop, args=(ser,))
	thread.start()

	values = [0.0]*18

	t = 0.0
	while True:
		dt = 0.05
		proc(t,dt)
		t = t+dt
		time.sleep(dt)

	return 0

def readloop(ser):
	cnt=0
	while cnt<20:
		data = ser.read(512)
		if len(data)>0:
			print "ser in: "+repr(data)
		else:
			#print "ser in <none>"
			time.sleep(0.25)
		cnt += 1


def proc(t,dt):
	global ser
	global values

#	ol = list()
#	dat = (''.join(ol))+"SEQ-END."
#	del ol

	v1 = int(t*4096) & 2047
	v1 = (v1-1023.5)/1023.5
	v1 *= 0.5

	v2 = int(t*512) & 4095
	if v2>=2048: v2=4096-v2
	v2 = (v2-1023.5)/1023.5
	v2 *= 0.5

	v3 = int(t*65536.0) & 0xFFFF
	v3 = v3*(math.pi/32768.0)
	v4 = 0.5 * math.sin(v3)
	v3 = 0.5 * math.cos(v3)


	dat = build_frame((v1,v2,v3,v4))
#	dat = build_frame((0.0,0.0,0.0,v2))
#	dat = "S\x00\x0C3456789abcdef0123456789ABCDEF0123456C"

#	if t<2.0:
#		print "sending: " + repr(dat)[:70]
	ser.write(dat)


# build frame. values are -1.0 .. 1.0
def build_frame(values):
	res = list()
	res.append('S'+chr(0)+chr(12))
	for i in xrange(12):
		val1,val2 = 0.0,0.0
		if i<len(values):
			val1 = values[i]
		val1 = int((val1+1.0)*2047.5+0.5)
		val1 = min(max(val1,0),4095)
		val2 = int((val2+1.0)*2047.5+0.5)
		val2 = min(max(val2,0),4095) ^ 2048

		res.append( chr(val1>>4) + chr((val1&15)+(val2>>8)) + chr(val2&255) )

	res = ''.join(res)
	return res + calcCRC8(res)


CRCtab = None
def calcCRC8(bytes):
	global CRCtab
	if CRCtab is None:
		lt,dummy = make_looptable()
		CRCtab = lt
	sr=0xFF
	for b in bytes:
		sr = CRCtab[sr^ord(b)]
	return chr(sr)


def make_looptable():
	looptab = list()
	outtab = list()
	poly = 0x1FA & 0xFF
	for t in xrange(256):
		sr=t
		outVal=0
		for s in xrange(8):
			outVal = outVal<<1
			if (sr&1):
				sr=(sr>>1)^poly
				outVal+=1
			else:
				sr=sr>>1
		looptab.append(sr)
		outtab.append(outVal)
	return looptab,outtab


if __name__=='__main__':
	sys.exit(main(sys.argv[1:]))


#	dat = build_sbus_frame((0.33333,0.0,0.0,0.0))

#	print repr(dat)
#	print len(dat)

