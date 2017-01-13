#!/usr/bin/env python

# program to try out the servo-over-sbus controlling

# format of sbus:


import math
import serial
import sys
import threading
import time
import two_lever_geometry


baudrate = 115200
serport = '/dev/ttyUSB0'

POINTS = ((-90.0,145.0),(0.0,200.0),(90.0,140.0))


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

nP = 0
curpos = POINTS[0]
def proc(t,dt):
	global ser
	global values
	global nP
	global curpos

#	ol = list()
#	dat = (''.join(ol))+"SEQ-END."
#	del ol

	# move to point
	SPEED = 80.0 # mm/sec
	P = POINTS[nP]
	dx,dy = P[0]-curpos[0] , P[1]-curpos[1]
	d = math.sqrt(dx*dx+dy*dy)
	spd = SPEED*dt
	if d>spd:
		q = spd/d
		curpos = ( curpos[0]+q*dx , curpos[1]+q*dy )
	else:
		curpos = P
		nP = (nP+1) % len(POINTS)
	#calc angles for this
	ang1,ang2 = two_lever_geometry.calc_servo_angles_for_target(curpos)

	# convert to servo-values. 
	v1 = ang1/-48.4
	v2 = ang2/-48.4

	v3 = int(t*4096) & 2047
	v3 = (v3-1023.5)/1023.5
	v3 *= 0.5

	v4 = int(t*512) & 4095
	if v4>=2048: v4=4096-v4
	v4 = (v4-1023.5)/1023.5
	v4 *= 0.5

	v5 = int(t*65536.0) & 0xFFFF
	v5 = v5*(math.pi/32768.0)
	v6 = 0.5 * math.sin(v5)
	v5 = 0.5 * math.cos(v5)

#	# 3 moves the positions -0.75,0,+.75,0
#	_t = int(t*0.6667+0.5)
#	v3 = (0.0,-0.75,0,0.75)[_t&3]


	dat = build_frame((v1,v2,v3,v4,v5,v6))
#	dat = build_frame((v3,v4,v5,v6,v1,v2))
#	dat = "S\x00\x0C3456789abcdef0123456789ABCDEF0123456C"

	if t<2.0:
		print "sending: " + repr(dat)[:70]
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

		res.append( chr(val1&255) + chr((val1>>8)+((val2&15)<<4)) + chr(val2>>4) )

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

