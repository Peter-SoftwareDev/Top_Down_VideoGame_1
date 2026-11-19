@tool
extends Node2D
## Gray-box stone floor.

@export var size: Vector2 = Vector2(1400, 900):
	set(value):
		size = value
		queue_redraw()
@export var tile: float = 64.0

func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, Color(0.2, 0.19, 0.21))
	var cols := int(size.x / tile)
	var rows := int(size.y / tile)
	for gx in cols:
		for gy in rows:
			var h: int = absi((gx * 73856093) ^ (gy * 19349663))
			if h % 7 == 0:
				var p := r.position + Vector2(gx, gy) * tile
				draw_rect(Rect2(p + Vector2(2, 2), Vector2(tile - 4, tile - 4)), Color(0, 0, 0, 0.12))
	var x := r.position.x
	while x <= r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.22), 1.0)
		x += tile
	var y := r.position.y
	while y <= r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, 0.22), 1.0)
		y += tile
