class_name MountainRidge
extends StaticBody2D
## A real impassable 2.5D Martian ridge, not a flat tile decal. The top-down silhouette
## is shaded in broad pixel-art steps; the convex shape forces EVA routes around it.
## No interactive climb: landings, science markers and mission trails stay reachable.

@export var span: float = 168.0
@export var height: float = 108.0
@export var rocky: bool = true


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 0
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([
		Vector2(-span * 0.49, 4),
		Vector2(-span * 0.36, -height * 0.42),
		Vector2(-span * 0.12, -height * 0.56),
		Vector2(span * 0.28, -height * 0.44),
		Vector2(span * 0.49, -height * 0.05),
		Vector2(span * 0.37, height * 0.40),
		Vector2(-span * 0.10, height * 0.46),
		Vector2(-span * 0.44, height * 0.27),
	])
	var body := CollisionShape2D.new()
	body.name = "RidgeCollision"
	body.shape = shape
	add_child(body)
	queue_redraw()


func _draw() -> void:
	var u := span / 168.0
	var v := height / 108.0
	# The lower eastern slope gets light from the same upper-left sun as the rest
	# of the art. Jagged bands convey height without needing 3D sprites.
	_poly([[-85,7],[-66,-40],[-22,-64],[36,-55],[84,-10],[63,43],[13,54],[-59,40]], "25131c",u,v)
	_poly([[-78,4],[-61,-35],[-18,-59],[33,-50],[77,-7],[57,36],[7,47],[-54,34]], "8b3524",u,v)
	_poly([[-72,-8],[-57,-41],[-15,-62],[31,-52],[66,-20],[46,13],[-2,24],[-51,12]], "d05b34",u,v)
	_poly([[-70,-12],[-48,-44],[-13,-57],[19,-46],[46,-21],[22,-1],[-20,9],[-54,2]], "ed8a4a",u,v)
	_poly([[-56,-24],[-27,-48],[-7,-53],[11,-42],[-6,-25],[-35,-16]], "ffc281",u,v)
	# Lower terrace is a naturally impassable cliff face, not a painted shadow.
	_poly([[-72,7],[-49,13],[-24,25],[4,20],[29,15],[47,27],[57,36],[7,47],[-54,34]], "64263a",u,v)
	_poly([[-58,19],[-29,31],[2,27],[24,20],[39,30],[18,36],[-27,38]], "a4402a",u,v)
	for y in [12,22,32]:
		var x := -36 if y == 12 else (-26 if y == 22 else -6)
		draw_line(Vector2(x*u,y*v),Vector2((x+42)*u,y*v),Color("de7242"),2)
	# Fracture ridges, spurs and small pockets of contrasting hematite.
	for pts in [ [[-44,-17],[-27,-31],[-13,-29]], [[-18,-49],[4,-39],[13,-26]], [[26,-40],[40,-21],[35,-10]] ]:
		var path := PackedVector2Array()
		for pt in pts:
			path.append(Vector2(pt[0]*u,pt[1]*v))
		draw_polyline(path,Color("86312b"),2.0)
	for p in [Vector2(-57,28),Vector2(-13,39),Vector2(41,27)]:
		var a: Vector2 = p * Vector2(u,v)
		draw_rect(Rect2(a, Vector2(7*u,3*v)),Color("e47740"))
		draw_rect(Rect2(a+Vector2(2*u, -2*v),Vector2(3*u,2*v)),Color("ffa45a"))


func _poly(coords: Array, tint: String, u: float, v: float) -> void:
	var points := PackedVector2Array()
	for point in coords:
		points.append(Vector2(float(point[0])*u,float(point[1])*v))
	draw_colored_polygon(points, Color(tint))
