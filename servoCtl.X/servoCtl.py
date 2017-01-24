#!/usr/bin/env python

import time
try:
	import serial
	_have_ser = True
except:
	_have_ser = False


baudrate = 115200
serport = '/dev/ttyUSB0'


class dummyfile(object):
	__slots__=()
	def __init__(self):
		pass

	def read(self,num):
		return ""

	def write(self,data):
		return None

	def close(self):
		pass


def open_serial(some_cfg_param=None):
	nam = some_cfg_param
	if nam is None:
		nam = serport
	if _have_ser:
		ser = serial.Serial(nam,baudrate,timeout=0,parity=serial.PARITY_NONE,stopbits=serial.STOPBITS_ONE,bytesize=8,rtscts=False,xonxoff=False)

		print "sending to %s" % nam
	else:
		ser = dummyfile()
		print "Don't have serial. debug-mode without output."

	return ser




# build frame. values are -1.0 .. 1.0
_build_frame_last = None
def build_frame(values,dt):
	global _build_frame_last
	if _build_frame_last is None:
		_build_frame_last = values
	if (dt is None) or (dt<=0.0):
		_build_frame_last = values
		dt=1.0
	# build packet
	res = list()
	res.append('S'+chr(0)+chr(12)) # static header
	for i in xrange(12):
		val,val_last = 0.0,0.0
		if i<len(values):
			val = values[i]
		if i<len(_build_frame_last):
			val_last = _build_frame_last[i]
		# make val,speed
		val1 = val_last
		val2 = (val-val_last)/dt
		val2 /= 100.0
		val1 = int((val1+1.0)*2047.5+0.5)
		val1 = min(max(val1,0),4095)
		val2 = int((val2+1.0)*2047.5+0.5)
		val2 = min(max(val2,0),4095) ^ 2048
		#val2 = 0

		res.append( chr(val1&255) + chr((val1>>8)+((val2&15)<<4)) + chr(val2>>4) )

	_build_frame_last = values

	# join, add CRC and return it.
	res = ''.join(res)
	return res + calcCRC8(res)

def dbg_print_frame(fram):
	if len(fram)!=40:
		print "Frame (bad length)"
		return
	_sta = 'ok'
	if fram[39]!=calcCRC8(fram[:39]):
		_sta = 'bad'
	print "Frame (CRC %s)" % _sta
	ll = list()
	for ch in xrange(6):
		a,b,c = fram[3+3*ch:6+3*ch]
		_p = ord(a) + (ord(b)&15)*256
		_s = (ord(b)>>4) + (ord(c))*16
		if _s>=2048:
			_s -= 4096
		ll.append("%4d:%5d"%(_p,_s))
	print "    %s    %s    %s" % tuple(ll[:3])
	print "    %s    %s    %s" % tuple(ll[3:6])


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





def time_control_loop(dt,max_lagbehind,warn_lag=False):
	""" controls the flow of time. returns a (sim-time,dt) each step, delays call to match realtime as good as possible. """
	if (not isinstance(dt,float)) or (dt<0.001) or (dt>300.0):
		raise ValueError("invalid dt %s"%repr(dt))
	if (not isinstance(max_lagbehind,float)) or (max_lagbehind<0.001) or (max_lagbehind>3600.0):
		raise ValueError("invalid max_lagbehind %s"%repr(max_lagbehind))
	t = 0.0
	toff = t-time.time()
	while True:
		yield (t,dt)
		t = t+dt
		_rt = time.time()+toff
		_wait = t-_rt
		if _wait>0.0:
			# ahead. delay
			time.sleep(_wait)
		elif _wait<-max_lagbehind:
			# too far behind. adjust offset a little.
			_over = -(max_lagbehind+_wait)
			if warn_lag:
				print "...lagging...%.3fsec" % (_over,)
			toff -= _over



if __name__=='__main__':
	print "module not to be called by itself..."
