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

#POINTS = ((-90.0,155.0),(0.0,200.0),(90.0,150.0))
#POINTS = ((-60.0,145.0),(-30.0,180.0),(30.0,180.0),(60.0,145.0))
POINTS = ((60.0,145.0),(30.0,180.0),(-30.0,180.0),(-60.0,145.0))


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
	toff = t-time.time()
	while True:
		dt = 0.05
		proc(t,dt)
		t = t+dt
		_rt = time.time()+toff
		if _rt<t:
			# ahead. delay
			time.sleep(dt)
		elif _rt>0.5:
			# too far behind. adjust offset a little.
			toff -= (_rt-0.5)

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
lastang = None
def proc(t,dt):
	global ser
	global values
	global nP
	global curpos

#	ol = list()
#	dat = (''.join(ol))+"SEQ-END."
#	del ol

	# move to point
	SPEED = 100.0 # mm/sec
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
	fac = 2.0/two_lever_geometry.SERVO_ANG_PER_MILLISEC
	ang1*=fac
	ang2*=fac
	global lastang
	if lastang is None: lastang = ang1,ang2
	v1 = ang1 , (ang1-lastang[0])/dt
	v2 = ang2 , (ang2-lastang[1])/dt
	lastang = ang1,ang2

	# DEBUG: send static values for measuring geometry.
#	v1 = -0.8,0.0
#	v2 = 0.8,0.0

	v3 = (t*2.0)%1.0
	v3 = v3-0.5 , 2.0

	v4 = (t*0.5)%2.0
	if v4<1.0:
		v4 = v4-0.5 , 0.5
	else:
		v4 = 1.5-v4 , -0.5

	v5 = (t%1.0)*math.pi*2.0
	v6 = 0.5 * math.sin(v5) , 0.5 * math.pi*2.0 * math.cos(v5)
	v5 = 0.5 * math.cos(v5) , 0.5 * math.pi*2.0 * -math.sin(v5)

#	# 3 moves the positions -0.75,0,+.75,0
#	_t = int(t*0.6667+0.5)
#	v3 = (0.0,-0.75,0,0.75)[_t&3]


	dat = build_frame((v1,v2,v3,v4,v5,v6))
#	dat = build_frame((v3,v4,v5,v6,v1,v2))
#	dat = "S\x00\x0C3456789abcdef0123456789ABCDEF0123456C"

	if t<2.0:
		#print "sending: " + repr(dat)[:70]
		#print "send: " + string4c(dat) + ","
		print "send:  %5.2f/%5.2f  %5.2f/%5.2f  %5.2f/%5.2f  %5.2f/%5.2f  %5.2f/%5.2f" % (v1[0],v1[1],v2[0],v2[1],v3[0],v3[1],v4[0],v4[1],v5[0],v5[1])
	ser.write(dat)


# build frame. values are -1.0 .. 1.0
def build_frame(values):
	res = list()
	res.append('S'+chr(0)+chr(12))
	for i in xrange(12):
		val1,val2 = 0.0,0.0
		if i<len(values):
			val1,val2 = values[i]
		val2 /= 100.0
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


def string4c(st):
	res = list()
	for c in st:
		cc = ord(c)
		if cc>=32 and cc<126 and c!="'" and c!='"' and c!="\\":
			res.append(c)
		else:
			res.append( "\\" + (("00"+oct(cc))[-3:]) )
	return '"'+(''.join(res))+'"'


if __name__=='__main__':
	sys.exit(main(sys.argv[1:]))


#	dat = build_sbus_frame((0.33333,0.0,0.0,0.0))

#	print repr(dat)
#	print len(dat)




