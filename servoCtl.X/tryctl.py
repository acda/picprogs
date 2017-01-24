#!/usr/bin/env python

# program to try out the servo-over-sbus controlling

# format of sbus:


import sys
import threading
import time
import pather
import servoCtl


POINTS = ((30.0,145.0,True),(30.0,180.0,True),(-30.0,180.0,True),(-30.0,145.0,False))

DT = 0.05

ser = None
pth = None

def main(args):

	global ser
	global pth
	global _have_ser

	ser = servoCtl.open_serial()

	pth = pather.pather()
	pth.add_coordinates_iterable(POINTS)
	pth.add_coordinates_iterable(POINTS)

	t = 0.0
	toff = t-time.time()
	for (t,dt) in servoCtl.time_control_loop(DT,0.5):
		if not proc(t,dt):
			break

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
	global pth

	vec = pth.get_vector(dt)

	dat = servoCtl.build_frame(vec,dt)
#	dat = "S\x00\x0C3456789abcdef0123456789ABCDEF0123456C"

	if dat is None:
		return False
	if t<3.0:
		#print "sending: " + repr(dat)[:70]
		#print "send: " + string4c(dat) + ","
		print "send:  %5.2f  %5.2f  %5.2f  %5.2f  %5.2f  %5.2f" % (vec[0],vec[1],vec[2],vec[3],vec[4],vec[5])
		#servoCtl.dbg_print_frame(dat)
		#print repr(vec)[:99]

	global ser
	ser.write(dat)
	return True





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



