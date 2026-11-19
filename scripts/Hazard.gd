@tool
extends Node2D
## A pit or a pool of deep water.
##
## Anything walking is stopped by its rim. An enemy that is knocked back
## slides over the rim, and once its centre is past `edge_margin` it falls or drowns.
## The player can never fall in (for now).

const L = preload("res://scripts/Layers.gd")

enum Kind { PIT, DEEP_WATER }

@export var kind: Kind = Kind.PIT:
	set(value):
		kind = value
		queue_redraw()
@export var size: Vector2 = Vector2(200, 120):
	set(value):
		size = value
		queue_redraw()
## How far past the rim an enemy's centre must go before it falls in.
@export var edge_margin: float = 10.0

var _time := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("hazard")
	var rim := StaticBody2D.new()
	rim.collision_layer = L.HAZARD_EDGE
	rim.collision_mask = 0
	rim.add_child(_rect_shape(size))
	add_child(rim)
	var zone := Area2D.new()
	zone.collision_layer = L.HAZARD_ZONE
	zone.collision_mask = 0
	zone.monitoring = false
	zone.add_child(_rect_shape(size - Vector2.ONE * edge_margin * 2.0))
	add_child(zone)

func _rect_shape(s: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = s
	cs.shape = rect
	return cs

func kill_cause() -> String:
	return "pit" if kind == Kind.PIT else "water"

func _process(delta: float) -> void:
	if kind == Kind.DEEP_WATER:
		_time += delta
		queue_redraw()

func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	if kind == Kind.PIT:
		draw_rect(r, Color(0.01, 0.01, 0.015))
		for i in 4:
			draw_rect(r.grow(-4.0 - i * 6.0), Color(0.16, 0.13, 0.12, 0.35 - i * 0.08), false, 3.0)
		draw_rect(r, Color(0.42, 0.36, 0.32), false, 4.0)
	else:
		draw_rect(r, Color(0.05, 0.13, 0.22))
		draw_rect(r.grow(-edge_margin), Color(0.03, 0.08, 0.15))
		var rows := int(size.y / 28.0)
		for row in rows:
			var y := -size.y * 0.5 + 14.0 + row * 28.0
			var pts := PackedVector2Array()
			var x := -size.x * 0.5 + 8.0
			while x <= size.x * 0.5 - 8.0:
				pts.append(Vector2(x, y + sin(x * 0.05 + _time * 2.0 + row) * 3.0))
				x += 12.0
			if pts.size() >= 2:
				draw_polyline(pts, Color(0.35, 0.55, 0.75, 0.25), 1.5)
		draw_rect(r, Color(0.35, 0.4, 0.42), false, 4.0)
