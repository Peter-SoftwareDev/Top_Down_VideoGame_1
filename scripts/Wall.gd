@tool
extends StaticBody2D
## A solid block of masonry. Set `size` in the inspector; the collision box follows it.

const L = preload("res://scripts/Layers.gd")

@export var size: Vector2 = Vector2(64, 64):
	set(value):
		size = value
		queue_redraw()
## A low barricade: you can't walk through it, but guards see over it
## unless you're crouching behind it.
@export var low: bool = false:
	set(value):
		low = value
		queue_redraw()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = L.LOW_WALL if low else L.WORLD
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)
	if not low:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		var h := size * 0.5
		poly.polygon = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
		occ.occluder = poly
		add_child(occ)

func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	if low:
		draw_rect(r, Color(0.33, 0.31, 0.3))
		draw_rect(r, Color(0.18, 0.16, 0.16), false, 2.0)
		var step := 12.0
		var x := r.position.x + step
		while x < r.end.x:
			draw_line(Vector2(x, r.position.y + 2), Vector2(x, r.end.y - 2), Color(0.22, 0.2, 0.2), 1.0)
			x += step
		var y := r.position.y + step
		while y < r.end.y:
			draw_line(Vector2(r.position.x + 2, y), Vector2(r.end.x - 2, y), Color(0.22, 0.2, 0.2), 1.0)
			y += step
		return
	draw_rect(r, Color(0.24, 0.23, 0.27))
	draw_rect(Rect2(r.position, Vector2(size.x, minf(8.0, size.y))), Color(0.34, 0.32, 0.36))
	draw_rect(r, Color(0.1, 0.09, 0.11), false, 2.0)
