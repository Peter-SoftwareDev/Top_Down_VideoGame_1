@tool
extends StaticBody2D
## A solid block of masonry. Set `size` in the inspector; the collision box follows it.

const L = preload("res://scripts/Layers.gd")

@export var size: Vector2 = Vector2(64, 64):
	set(value):
		size = value
		queue_redraw()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = L.WORLD
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)

func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, Color(0.24, 0.23, 0.27))
	draw_rect(Rect2(r.position, Vector2(size.x, minf(8.0, size.y))), Color(0.34, 0.32, 0.36))
	draw_rect(r, Color(0.1, 0.09, 0.11), false, 2.0)
