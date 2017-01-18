#!/usr/bin/env python

# program to try out the servo-over-sbus controlling

# format of sbus:


import math
import sys
import threading
import time
import two_lever_geometry
import servoCtl


#POINTS = ((-90.0,155.0),(0.0,200.0),(90.0,150.0))
#POINTS = ((-60.0,145.0),(-30.0,180.0),(30.0,180.0),(60.0,145.0))
#POINTS = ((60.0,145.0),(30.0,180.0),(-30.0,180.0),(-60.0,145.0))
POINTS = ((30.0,145.0),(30.0,180.0),(-30.0,180.0),(-30.0,145.0))

ser = None

def main(args):

	global ser
	global values
	global _have_ser

	ser = servoCtl.open_serial()

	values = [0.0]*18

	t = 0.0
	toff = t-time.time()
	for (t,dt) in servoCtl.time_control_loop(0.05,0.5):
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

nP = 0
curpos = POINTS[0]
def proc(t,dt):
	global values
	global nP
	global curpos

	# move to point
	SPEED = 200.0 # mm/sec
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
	v1 = ang1*fac
	v2 = ang2*fac

	# DEBUG: send static values for measuring geometry.
#	v1 = -0.8
#	v2 = 0.8

	v3 = (t*2.0)%1.0
	v3 = v3-0.5

	v4 = (t*0.5)%2.0
	if v4<1.0:
		v4 = v4-0.5
	else:
		v4 = 1.5-v4

	v5 = (t%1.0)*math.pi*2.0
	v6 = 0.5 * math.sin(v5)
	v5 = 0.5 * math.cos(v5)

#	# 3 moves the positions -0.75,0,+.75,0
#	_t = int(t*0.6667+0.5)
#	v3 = (0.0,-0.75,0,0.75)[_t&3]


	dat = servoCtl.build_frame((v1,v2,v3,v4,v5,v6,v5,v6,v5,v6,v5,v6),dt)
#	dat = servoCtl.build_frame((v3,v4,v5,v6,v1,v2),dt)
#	dat = "S\x00\x0C3456789abcdef0123456789ABCDEF0123456C"

	if t<3.0:
		#print "sending: " + repr(dat)[:70]
		#print "send: " + string4c(dat) + ","
		print "send:  %5.2f  %5.2f  %5.2f  %5.2f  %5.2f  %5.2f" % (v1,v2,v3,v4,v5,v6)

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



