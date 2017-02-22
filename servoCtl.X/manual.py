#!/usr/bin/env python

# program to try out the servo-over-sbus controlling

# format of sbus:


import math
import sys
import time
try:
	import serial
	_have_ser = True
except:
	_have_ser = False
import noncanon_input
import servoCtl


cio = None
ser = None

def main(args):

	global cio
	global ser
	global values

	ser = servoCtl.open_serial()

	cio = noncanon_input.cio()

	values = [0.0]*18

	t = 0.0
	toff = t-time.time()
	for (t,dt) in servoCtl.time_control_loop(0.10,0.5):
		if not proc(t,dt):
			break

	del cio

	return 0


ch = 0
mag = 1.0/16.0
def proc(t,dt):
	global ch
	global cio
	global mag
	global values

	# poll input
	while True:
		b = cio.getch()
		if b is None:
			break
		if len(b)==1 and b.isdigit():
			ch = int(b)
			cio.puts( "channel #%u\n" % (ch,) )
		elif len(b)==1 and ord(b)>=ord('a') and ord(b)<=ord('g'):
			mag = 1.0
			for i in xrange(ord(b)-ord('a')):
				mag = mag/4.0
			cio.puts( "stepsize = %.6f\n" % (mag,) )
		elif b=='\x1b[D': # cursor left
			v = max( values[ch]-mag , -1.0 )
			values[ch] = v
			cio.puts( "left %7.4f\n" % (v,) );
		elif b=='\x1b[C': # cursor right
			v = min( values[ch]+mag , 1.0 )
			values[ch] = v
			cio.puts( "right%7.4f\n" % (v,) );
		elif b==' ':
			cio.puts( "  ".join("%.4f"%b for b in values[:10]) + '\n' )
		elif b=='q':
			return False
		else:
			cio.puts( "ignored input  %s\n" % (repr(b),) )


	dat = servoCtl.build_frame(values,dt)

	global ser
	ser.write(dat)
	return True




if __name__=='__main__':
	sys.exit(main(sys.argv[1:]))
