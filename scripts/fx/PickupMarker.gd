extends Node2D
## A bobbing marker drawn above the darkness so dropped ammo is easy to spot.
## Follows its pickup and disappears with it.

var target: Node2D
var kind := "bolt"
var _t := 0.0

func _ready() -> void:
	z_index = 80
	_t = randf() * TAU

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	_t += delta
	global_position = target.global_position
	queue_redraw()

func _draw() -> void:
	var c := Color(1.0, 0.78, 0.4) if kind == "bolt" else Color(0.75, 0.82, 0.95)
	var bob := sin(_t * 3.0) * 3.0
	# Ground ring where it actually lies.
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 20, Color(c.r, c.g, c.b, 0.55), 1.5)
	# Chevron pointing down at it.
	var tip := Vector2(0, -16 + bob)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-6, -8), tip + Vector2(6, -8)]), Color(c.r, c.g, c.b, 0.9))
	# Tiny icon of what it is.
	var icon := tip + Vector2(0, -15)
	if kind == "bolt":
		draw_line(icon + Vector2(-5, 2), icon + Vector2(5, -2), c, 2.0)
	else:
		draw_circle(icon, 3.5, c)
