#!/usr/bin/env python

import math
import two_lever_geometry

POINTS = ((30.0,145.0,True),(30.0,180.0,True),(-30.0,180.0,True),(-30.0,145.0,False))

VAL_UP = -0.8
VAL_DOWN = 0.2

SPEED = 150.0 # mm/sec
UD_SPEED = 3.0


class pather(object):
	__slots__ = ("dt","t","curpos","down","iters","iterator","toP")

	def __init__(self):
		self.t = 0.0
		self.dt = 0.02
		if self.dt<=0.0 or self.dt>0.2:
			raise ValueError("bad dt")
		self.curpos = None
		self.down = 0.0
		self.iters = list()
		self.iterator = xrange(0).__iter__()
		self.toP = None

	def add_coordinates_iterable(self,iter):
		self.iters.append(iter)

	def get_vector(self,dt):
		self.dt = float(dt)
		if self.dt<=0.0 or self.dt>0.2:
			raise ValueError("bad dt")

		while self.toP is None:
			try:
				self.toP = self.iterator.next()
				print "self.toP = " + repr(self.toP)
				if self.curpos is None:
					self.curpos = self.toP
				break
			except StopIteration:
				if len(self.iters)<1:
					break	# all out.
				_i = self.iters[0]
				del self.iters[0]
				self.iterator = _i.__iter__()
		if self.toP is None:
			return None

		# lower/raise ?
		if (not self.toP[2]) and self.down>0.0:
			self.down = max( self.down-UD_SPEED*dt , 0.0 )
		elif self.toP[2] and self.down<1.0:
			self.down = min( self.down+UD_SPEED*dt , 1.0 )
		else:
			# move to point
			dx,dy = self.toP[0]-self.curpos[0] , self.toP[1]-self.curpos[1]
			d = math.sqrt(dx*dx+dy*dy)
			spd = SPEED*self.dt
			if d>spd:
				q = spd/d
				self.curpos = ( self.curpos[0]+q*dx , self.curpos[1]+q*dy )
			else:
				self.curpos = self.toP
				self.toP = None

		#calc angles for this
		ang1,ang2 = two_lever_geometry.calc_servo_angles_for_target(self.curpos)

		# convert values 1 and 2 to servo-values. 
		fac = 2.0/two_lever_geometry.SERVO_ANG_PER_MILLISEC
		v1 = ang1*fac
		v2 = ang2*fac
		v3 = VAL_UP + self.down * (VAL_DOWN-VAL_UP)

		# DEBUG: send static values for measuring geometry.
#		v1 = -0.8
#		v2 = 0.8

		v4 = (self.t*0.5)%2.0
		if v4<1.0:
			v4 = v4-0.5
		else:
			v4 = 1.5-v4

		v5 = (self.t%1.0)*math.pi*2.0
		v6 = 0.5 * math.sin(v5)
		v5 = 0.5 * math.cos(v5)

#		# 3 moves the positions -0.75,0,+.75,0
#		_t = int(t*0.6667+0.5)
#		v3 = (0.0,-0.75,0,0.75)[_t&3]

		self.t += self.dt

		return (v1,v2,v3,v4,v5,v6,v5,v6,v5,v6,v5,v6)
#		return (v3,v4,v5,v6,v1,v2)







if __name__ == "__main__":
	raise Exception("Not for standalone use.")
