
import math

class vector2:
	""" Represents a 2D vector. """

	def __init__(self,x=0,y=0):
		self.x = float(x)
		self.y = float(y)

	def __add__(self, val):
		return Vector( self.x+val.x , self.y+val.y )

	def __sub__(self,val):
		return Vector( self.x-val.x , self.y-val.y )

	def __iadd__(self, val):
		self.x = val.x + self.x
		self.y = val.y + self.y
		return self

	def __isub__(self, val):
		self.x = self.x - val.x
		self.y = self.y - val.y
		return self

	def __div__(self, val):
		return Point( self.x/val , self.y/val )

	def __mul__(self, val):
		return Point( self.x*val , self.y*val )

	def __idiv__(self, val):
		self.x /= val
		self.y /= val
		return self

	def __imul__(self, val):
		self.x *= val
		self.y *= val
		return self

	def __getitem__(self, key):
		if key==0:
			return self.x
		elif key == 1:
			return self.y
		raise KeyError("Invalid key to vector2")

	def __setitem__(self, key, value):
		if key==0:
			self.x = value
		elif key == 1:
			self.y = value
		raise KeyError("Invalid key to vector2")

	def __str__(self):
		return "("+str(self.x)+"/"+str(self.y)+")"

	def __repr__(self):
		return "vector2("+repr(self.x)+","+repr(self.y)+")"

def DistanceSqrd( point1, point2 ):
	""" Returns the distance between two points squared. Marginally faster than Distance() """
	_dx = point1.x-point2.x
	_dy = point1.y-point2.y
	return (_dx*_dx+_dy*_dy)

def Distance( point1, point2 ):
	'Returns the distance between two points'
	return math.sqrt( DistanceSqrd(point1,point2) )

def LengthSqrd( vec ):
	'Returns the length of a vector sqaured. Faster than Length(), but only marginally'
	return vec.x*vec.x + vec.y*vec.y

def Length( vec ):
	'Returns the length of a vector'
	return math.sqrt( vec.x*vec.x + vec.y*vec.y )

def Normalize( vec ):
	'Returns a new vector that has the same direction as vec, but has a length of one.'
	return vec / Length(vec)

def Dot( a,b ):
	'Computes the dot product of a and b'
	return a.x*b.x + a.y*b.y

def ProjectOnto( w,v ):
	'Projects w onto v.'
	return v * Dot(w,v) / LengthSqrd(v)

