#!/usr/bin/env python

import math
import sys

# play around with the geometry of the two-lever system


# definition of mechanic. All numbers in millimeters. Vectors as 2D tuples. Angles as degrees. Zero-angle is to pos-X, 90-angle is to pos-Y.
ServoPos1 = (-25.0,0.0)
ServoPos2 = (25.0,0.0)
ServoNullAngle1 = 142.4
ServoNullAngle2 = 37.4
leverLen1a = 120.0
leverLen1b = 131.0
leverLen2a = 121.0
leverLen2b = 120.0
pen_pos_over_len =   -2.0
pen_pos_over_left = 23.0


def main(args):

	#p1 = (1.0,1.0)
	#p2 = (3.0,3.0)
	#cp = circles_cut( p1 , 1.9 , p2 , 1.5 )

	#for p in cp:
	#	dist1 = pointdist(p1,p)
	#	dist2 = pointdist(p2,p)
	#	print repr(p) , dist1 , dist2

	for i in xrange(30):
		p = (0.0,i*10.0)
		res = calc_servo_angles_for_target(p)
		a1,a2 = '<none>','<none>'
		if res[0] is not None:
			a1 = "%.1fdeg" % (res[0],)
		if res[1] is not None:
			a2 = "%.1fdeg" % (res[1],)
		print "point: (%.1f/%.1f)  angles: %s %s" % (p[0],p[1],a1,a2)


	# calc coverage diagram
	WIDTH = 100
	HEIGHT = 48
	ar = [(0.0,0.0)]*WIDTH*HEIGHT
	# loop all points
	for h in xrange(HEIGHT):
		y = (h+1)*5.0
		for w in xrange(WIDTH):
			x = (w-50)*5.0
			ar[w+WIDTH*h] = calc_servo_angles_for_target((x,y))

	maxx_d = 0.0
	res = [' ']*WIDTH*HEIGHT
	for h in xrange(HEIGHT):
		for w in xrange(WIDTH):
			a = ar[w+WIDTH*h]
			if w<=0 or h<=0 or w+1>=WIDTH or h+1>=HEIGHT:
				a = '#'
			elif (a[0] is None) or (a[1] is None):
				a = '.'
			else:
				au = ar[w+WIDTH*(h-1)]
				ad = ar[w+WIDTH*(h+1)]
				al = ar[w-1+WIDTH*h]
				aR = ar[w+1+WIDTH*h]
				a = 'X'
				if not ((au[0] is None) or (au[1] is None) or (ad[0] is None) or (ad[1] is None) or (al[0] is None) or (al[1] is None) or (aR[0] is None) or (aR[1] is None)):
					dx1 = aR[0]-al[0]
					dx2 = aR[1]-al[1]
					dy1 = ad[0]-au[0]
					dy2 = ad[1]-au[1]
					d1 = dx1*dx1+dy1*dy1
					d2 = dx2*dx2+dy2*dy2
					d = math.sqrt(max(d1,d2))
					maxx_d = max(d,maxx_d)
					colidx = min(int(d/2.0+0.5),25)
					a = chr(ord('a')+colidx)
			res[w+WIDTH*h] = a

	print "maxx_d = %.1f" % (maxx_d,)

	res = ''.join(res)
	for h in xrange(HEIGHT-1,-1,-1):
		print ("%3d "%(h+1)) + res[WIDTH*h:WIDTH*(h+1)]
	print
	print '    '+''.join(("%3u"%(w-50))[2] for w in xrange(WIDTH))
	print '    '+''.join(("%3u"%(w-50))[1] for w in xrange(WIDTH))
	print '    '+''.join(("%3u"%(w-50))[0] for w in xrange(WIDTH))


SERVO_LIMIT_DEG = 48.0
len1bgross = None	# calc'd on first use.

def calc_servo_angles_for_target(targetpoint):
	# calc points of joints
	global len1bgross
	global _pen2left
	if len1bgross is None:
		_x = leverLen1b + pen_pos_over_len
		_y = pen_pos_over_left
		len1bgross = math.sqrt(_x*_x+_y*_y)
		_pen2left = math.atan2(_y,_x)
	# calc first lever
	j1 = circles_cut(ServoPos1,leverLen1a,targetpoint,len1bgross)
	if len(j1)<1:
		return None,None
	elif len(j1)==1 or j1[0]<j1[1]:
		j1=j1[0]
	else:
		j1=j1[1]
	ang2b = math.atan2(targetpoint[1]-j1[1],targetpoint[0]-j1[0]) - _pen2left
	# calc connecting joint (which is not equal to pen position)
	j3 = ( j1[0]+math.cos(ang2b)*leverLen1b , j1[1]+math.sin(ang2b)*leverLen1b )
	# calc second lever
	j2 = circles_cut(ServoPos2,leverLen2a,j3,leverLen2b)
	if len(j2)<1:
		return None,None
	elif len(j2)==1 or j2[0]>j2[1]:
		j2=j2[0]
	else:
		j2=j2[1]
	a1=clampangle_deg(math.atan2(j1[1],j1[0])*180.0/math.pi-ServoNullAngle1)
	a2=clampangle_deg(math.atan2(j2[1],j2[0])*180.0/math.pi-ServoNullAngle2)
	if a1<-SERVO_LIMIT_DEG or a1>SERVO_LIMIT_DEG: a1=None
	if a2<-SERVO_LIMIT_DEG or a2>SERVO_LIMIT_DEG: a2=None

	return a1,a2


def clampangle_deg(ang):
	if ang<-180.0:
		return ang+360.0
	if ang>180.0:
		return ang-360.0
	return ang


def pointdist(p1,p2):
	dx = p2[0]-p1[0]
	dy = p2[1]-p1[1]
	return math.sqrt(dx*dx+dy*dy)

def circles_cut(p1,r1,p2,r2):
	# find transform
	dx = p2[0]-p1[0]
	dy = p2[1]-p1[1]
	rr = dx*dx+dy*dy
	if rr<=0.0:
		raise ValueError("same points")
	nf = 1.0/math.sqrt(rr)
	# transform matrix
	M = (dx*nf,-dy*nf,dy*nf,dx*nf)
	# now (inverse) transform
	pp1 = (0.0,0.0)
	pp2 = (M[0]*dx+M[2]*dy,M[1]*dx+M[3]*dy)
	#print "pp2 = " + repr(pp2)
	# pp2[0] should be > 0 , pp2[1] should be 0.
	if pp2[1]*pp2[1] >= 1.0e-5 * rr:
		raise Exception("Uh oh bad transform.")
	if pp2[0] <= 0.0:
		raise Exception("Uh oh bad transform (2).")
	# get x of cut-point
	# (x-x2)^2 + y^2 = r2^2
	# (x-x2)^2 + (r1^2 - x^2) = r2^2
	# -2*x*x2 + x2^2 = r2^2 - r1^2
	# -2*x*x2 = r2^2 - r1^2 - x2^2
	# x = ( r1^2 + x2^2 - r2^2 )/(2*x2)
	xcut = ( r1*r1 + pp2[0]*pp2[0] - r2*r2 )/(2.0*pp2[0])
	# from here, get ycut with
	# r1*r1 = x*x + y*y
	# y = sqrt(r1^2-x^2)
	#_rad = r1*r1 - xcut*xcut
	_rad = r2*r2 - (xcut-pp2[0])*(xcut-pp2[0])
	if _rad<0.0:
		ycut=()
	elif _rad<1.0e-6*rr:
		ycut=(0.0,)
	else:
		ycut=math.sqrt(_rad)
		ycut = (ycut,-ycut)

	#print "check: dist 1 = %.3f" % (pointdist((0.0,0.0),(xcut,ycut[0])))
	#print "check: dist 2 = %.3f" % (pointdist((pp2[0],0.0),(xcut,ycut[0])))

	# transform back
	res=list()
	for y in ycut:
		res.append((M[0]*xcut+M[1]*y+p1[0],M[2]*xcut+M[3]*y+p1[1]))

	return tuple(res)



if __name__=="__main__":
	main(sys.argv[1:])

