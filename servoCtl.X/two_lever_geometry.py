#!/usr/bin/env python

import math
import sys

# play around with the geometry of the two-lever system


# definition of mechanic. All numbers in millimeters. Vectors as 2D tuples. Angles as degrees. Zero-angle is to pos-X, 90-angle is to pos-Y.
ServoPos1 = (-22.5,0.0)
ServoPos2 = (22.5,0.0)
ServoNullAngle1 = 144.6
ServoNullAngle2 = 41.35
leverLen1a = 120.0
leverLen1b = 131.5
leverLen2a = 120.0
leverLen2b = 120.0
pen_pos_over_len =   -5.17
pen_pos_over_left = 22.4
SERVO_LIMIT_DEG = 47.0
SERVO_ANG_PER_MILLISEC = -95.0	# or 93.2 or 95.0 ?


# polygon of 'valid' target points. found by starting 'main' in here and entering it manually.
# automating this would be cool.
# define counterclockwise.
ValidArea = ( (-125.0,105.0) , (115.0,115.0) , (105.0,170.0) , (0.0,215.0) , (-105.0,170.0) )


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
	res1 = [' ']*WIDTH*HEIGHT
	res2 = [' ']*WIDTH*HEIGHT
	for h in xrange(HEIGHT):
		for w in xrange(WIDTH):
			a = ar[w+WIDTH*h]
			if w<=0 or h<=0 or w+1>=WIDTH or h+1>=HEIGHT:
				a1,a2 = '#','#'
			elif (a[0] is None) or (a[1] is None):
				a1,a2 = '.','.'
			else:
				au = ar[w+WIDTH*(h-1)]
				ad = ar[w+WIDTH*(h+1)]
				al = ar[w-1+WIDTH*h]
				aR = ar[w+1+WIDTH*h]
				a1 = 'X'
				if not ((au[0] is None) or (au[1] is None) or (ad[0] is None) or (ad[1] is None) or (al[0] is None) or (al[1] is None) or (aR[0] is None) or (aR[1] is None)):
					# calc gradient
					dx1 = aR[0]-al[0]
					dx2 = aR[1]-al[1]
					dy1 = ad[0]-au[0]
					dy2 = ad[1]-au[1]
					d1 = dx1*dx1+dy1*dy1
					d2 = dx2*dx2+dy2*dy2
					d = math.sqrt(max(d1,d2))
					# di is gradient of how much a move in x/y will affect servo rotations.
					maxx_d = max(d,maxx_d)
					colidx = min(int(d*1.0+0.5),25)
					a1 = chr(ord('a')+colidx)
				_da = 0.3333
				ppr_u = calc_pos_from_servo_angles(a[0]+_da,a[1])
				ppr_d = calc_pos_from_servo_angles(a[0]-_da,a[1])
				ppr_l = calc_pos_from_servo_angles(a[0],a[1]+_da)
				ppr_r = calc_pos_from_servo_angles(a[0],a[1]-_da)
				if not ((ppr_u is None) or (ppr_d is None) or (ppr_l is None) or (ppr_r is None)):
					dx1,dy1 = ppr_u[0]-ppr_d[0],ppr_l[0]-ppr_r[0]
					dx2,dy2 = ppr_u[1]-ppr_d[1],ppr_l[1]-ppr_r[1]
					d1 = dx1*dx1+dy1*dy1
					d2 = dx2*dx2+dy2*dy2
					d = math.sqrt(max(d1,d2))
					# di is gradient of how much a move in angles will affect x/y.
					maxx_d = max(d,maxx_d)
					colidx = min(int(d*2.0+0.5),25)
					a2 = chr(ord('a')+colidx)
			res1[w+WIDTH*h] = a1
			res2[w+WIDTH*h] = a2

	print "maxx_d = %.1f" % (maxx_d,)
	res1 = ''.join(res1)
	res2 = ''.join(res2)

	# print graph for gradient.
	print "\nGradient servoangle-per-linearmove"
	for h in xrange(HEIGHT-1,-1,-1):
		print ("%3d "%(h+1)) + res1[WIDTH*h:WIDTH*(h+1)]
	print
	print '    '+''.join(("%3u"%(w-50))[2] for w in xrange(WIDTH))
	print '    '+''.join(("%3u"%(w-50))[1] for w in xrange(WIDTH))
	print '    '+''.join(("%3u"%(w-50))[0] for w in xrange(WIDTH))

	# print graph for inverse.
	print "\nGradient linearmove-per-servoangle"
	for h in xrange(HEIGHT-1,-1,-1):
		print ("%3d "%(h+1)) + res2[WIDTH*h:WIDTH*(h+1)]
	print
	print '    '+''.join(("%3u"%(w-50))[2] for w in xrange(WIDTH))
	print '    '+''.join(("%3u"%(w-50))[1] for w in xrange(WIDTH))
	print '    '+''.join(("%3u"%(w-50))[0] for w in xrange(WIDTH))


len1bgross = None	# calc'd on first use.
def calc_len1bgross():
	global len1bgross
	global _pen2left
	_x = leverLen1b + pen_pos_over_len
	_y = pen_pos_over_left
	len1bgross = math.sqrt(_x*_x+_y*_y) # len1b to pen
	_pen2left = math.atan2(_y,_x)

def calc_servo_angles_for_target(targetpoint):
	# calc points of joints
	global len1bgross
	global _pen2left

#	# check against bounds.
#	_tp = restrict_point(targetpoint)
#	if _tp!=targetpoint:
#		return None,None

	if len1bgross is None:
		calc_len1bgross()
	# calc first lever
	j1 = circles_cut(ServoPos1,leverLen1a,targetpoint,len1bgross)
	if len(j1)<1:
		return None,None
	elif len(j1)==1 or j1[0][0]<j1[1][0]:
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
	elif len(j2)==1 or j2[0][0]>j2[1][0]:
		j2=j2[0]
	else:
		j2=j2[1]
	a1=clampangle_deg(math.atan2(j1[1]-ServoPos1[1],j1[0]-ServoPos1[0])*180.0/math.pi-ServoNullAngle1)
	a2=clampangle_deg(math.atan2(j2[1]-ServoPos2[1],j2[0]-ServoPos2[0])*180.0/math.pi-ServoNullAngle2)
	if a1<-SERVO_LIMIT_DEG or a1>SERVO_LIMIT_DEG: a1=None
	if a2<-SERVO_LIMIT_DEG or a2>SERVO_LIMIT_DEG: a2=None

	#if (a1 is not None) and (a2 is not None):
	#	_pp = calc_pos_from_servo_angles(a1,a2)
	#	if _pp is not None:
	#		_dx,_dy = _pp[0]-targetpoint[0] , _pp[1]-targetpoint[1]
	#		_d = math.sqrt(_dx*_dx+_dy*_dy)
	#		print "DEBUG: tp=(%5.1f/%5.1f)   _d=%.3f" % (targetpoint[0],targetpoint[1],_d)
	#	else:
	#		print "DEBUG: tp=(%5.1f/%5.1f)   _d=N/A" % (targetpoint[0],targetpoint[1])

	return a1,a2


def calc_pos_from_servo_angles(ang1,ang2):
	global len1bgross
	global _pen2left
	ang1 = (ang1+ServoNullAngle1)*math.pi/180.0
	ang2 = (ang2+ServoNullAngle2)*math.pi/180.0
	c1,s1 = math.cos(ang1),math.sin(ang1)
	c2,s2 = math.cos(ang2),math.sin(ang2)
	j1 = ServoPos1[0] + c1*leverLen1a , ServoPos1[1] + s1*leverLen1a
	j2 = ServoPos2[0] + c2*leverLen2a , ServoPos2[1] + s2*leverLen2a
	# limit against crossing
	if math.atan2(-j1[0],j1[1]) < math.atan2(-j2[0],j2[1]):
		return None
	# j3 from cut-of-circles.
	j3 = circles_cut(j1,leverLen1b,j2,leverLen2b)
	if len(j3)<1:
		return None
	if len(j3)<=1 or j3[0][1]>j3[1][1]:
		j3=j3[0]
	else:
		j3=j3[1]
	# now penpos.
	ang2b = math.atan2(j3[1]-j1[1],j3[0]-j1[0])
	if len1bgross is None:
		calc_len1bgross()
	penpos = j1[0]+math.cos(ang2b+_pen2left)*len1bgross , j1[1]+math.sin(ang2b+_pen2left)*len1bgross

	return penpos


ValidAreaEdges = None # filled in on first access
def restrict_point(point):
	global ValidArea
	global ValidAreaEdges
	if ValidAreaEdges is None:
		# pre-calc edge formulas. Each edge has normal and distance.
		# vectors point outward
		ValidAreaEdges = list()
		for i in xrange(len(ValidArea)):
			i2 = (i+1)%len(ValidArea)
			dx,dy = ValidArea[i2][0]-ValidArea[i][0] , ValidArea[i2][1]-ValidArea[i][1]
			_len = math.sqrt(dx*dx+dy*dy)
			nx,ny = dy/_len,-dx/_len
			dd = ValidArea[i][0]*nx + ValidArea[i][1]*ny
			ValidAreaEdges.append((nx,ny,dd))
	# ugly. just apply edges in order.
	for (nx,ny,dd) in ValidAreaEdges:
		_tmp = nx*point[0]+ny*point[1]
		if _tmp > dd:
			# point is outside. clamp onto edge.
			point = point[0]-(_tmp-dd)*nx , point[1]-(_tmp-dd)*ny
			###print "clamping to (%.1f/%.1f)" % point

	return point


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

