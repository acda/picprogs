#!/usr/bin/env python

# program to try out the servo-over-sbus controlling

# format of sbus:



import sys
import time
import serial
import threading


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
		dt = 0.018
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

	v = int(t*4096) & 2047
	v = (v-1023.5)/1023.5
	v *= 0.5
	dat = build_sbus_frame((v,0.0,0.0,0.0))

	print "sending: " + repr(dat)[:70]
	ser.write(dat)


# build frame. values are -1.0 .. 1.0
def build_sbus_frame(values):
	res = list()
	res.append(chr(15))
	bits=0
	nbits=0
	for i in xrange(16):
		val = 0.0
		if i<len(values):
			val = values[i]
		val = int((val+1.0)*1023.5)
		val = min(max(val,0),2047)
		bits += (val<<nbits)
		nbits += 11
		while nbits>=8:
			res.append(chr(bits&255))
			bits = bits>>8
			nbits -= 8
	val = 0
	if len(values)>=16 and values[16]>0.0:
		val += 1
	if len(values)>=17 and values[17]>0.0:
		val += 1
	res.append(chr(val))

	val = 0
	res.append(chr(val))

	return ''.join(res)


if __name__=='__main__':
	sys.exit(main(sys.argv[1:]))


#	dat = build_sbus_frame((0.33333,0.0,0.0,0.0))

#	print repr(dat)
#	print len(dat)

