class_name CaveTracks
extends Node2D
## A physical breadcrumb trail left by Sojourner's wheels, leading from
## the lower tunnel towards the rover and sediment scan in the dark.

const TRACK := Color(0.28, 0.12, 0.105, 0.86)
const RIM := Color(0.58, 0.29, 0.20, 0.64)
const SCUFF := Color(0.44, 0.17, 0.12, 0.58)
var points: PackedVector2Array = PackedVector2Array([
	Vector2(514, 523), Vector2(510, 479), Vector2(496, 426),
	Vector2(514, 385), Vector2(565, 355), Vector2(617, 312),
	Vector2(662, 265), Vector2(716, 236), Vector2(756, 211),
])

func _ready() -> void:
	z_index = -1
	queue_redraw()


func _draw() -> void:
	# Tiny staggered chevrons, two parallel tracks with disturbed dust in between.
	for segment in range(points.size() - 1):
		var start: Vector2 = points[segment]
		var finish: Vector2 = points[segment + 1]
		var travel: Vector2 = finish - start
		var distance: float = travel.length()
		if distance < 1.0:
			continue
		var forward: Vector2 = travel / distance
		var sideways: Vector2 = Vector2(-forward.y, forward.x)
		var count: int = maxi(1, int(distance / 7.0))
		for i in range(count + 1):
			var along: float = (float(i) / float(count)) * distance
			var at: Vector2 = start + forward * along
			for side_value in [-1.0, 1.0]:
				var side: float = float(side_value)
				var tread: Vector2 = (at + sideways * side * 8.0).round()
				draw_line(tread - sideways * 3.0, tread + sideways * 3.0, RIM, 3.0)
				draw_line(tread - sideways * 2.0, tread + sideways * 2.0, TRACK, 2.0)
			if i % 3 == 0:
				draw_rect(Rect2((at - Vector2(1, 1)).round(), Vector2(3, 2)), SCUFF)
			if i % 5 == 1:
				draw_rect(Rect2((at + sideways * 15.0).round(), Vector2(3, 2)), RIM)
