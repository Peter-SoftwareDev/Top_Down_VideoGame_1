@tool
extends Node2D
## A pit or a pool of deep water.
##
## Anything walking is stopped by its rim. Anything knocked back slides over the rim,
## and once its centre is past `edge_margin` it falls in (or drowns).
## A `crumbles` pit gives way under a body that skids to a stop on its rim,
## and the pit grows a little on that side.

const L = preload("res://scripts/Layers.gd")
const Fx = preload("res://scripts/Fx.gd")

enum Kind { PIT, DEEP_WATER }

@export var kind: Kind = Kind.PIT:
	set(value):
		kind = value
		queue_redraw()
@export var size: Vector2 = Vector2(200, 120):
	set(value):
		size = value
		area = Rect2(-size * 0.5, size)
		queue_redraw()
## How far past the rim a centre must go before it falls in.
@export var edge_margin: float = 10.0
## Pits only: the rim breaks under anything that skids to a stop on it.
@export var crumbles: bool = false:
	set(value):
		crumbles = value
		queue_redraw()
## How many times the rim can crumble before it's solid rock.
@export var max_crumbles: int = 4

const CRUMBLE_REACH := 10.0   # A stop this close outside the rim still crumbles it.
const CRUMBLE_STEP := 26.0    # How much the pit grows per crumble.

var area := Rect2(-100, -60, 200, 120)
var crumble_count := 0
var rubble: Array[Rect2] = []
var _time := 0.0
var _rim_shape: RectangleShape2D
var _rim_cs: CollisionShape2D
var _zone_shape: RectangleShape2D
var _zone_cs: CollisionShape2D

func _ready() -> void:
	area = Rect2(-size * 0.5, size)
	if Engine.is_editor_hint():
		return
	add_to_group("hazard")
	var rim := StaticBody2D.new()
	rim.collision_layer = L.HAZARD_EDGE
	rim.collision_mask = 0
	_rim_cs = CollisionShape2D.new()
	_rim_shape = RectangleShape2D.new()
	_rim_cs.shape = _rim_shape
	rim.add_child(_rim_cs)
	add_child(rim)
	var zone := Area2D.new()
	zone.collision_layer = L.HAZARD_ZONE
	zone.collision_mask = 0
	zone.monitoring = false
	_zone_cs = CollisionShape2D.new()
	_zone_shape = RectangleShape2D.new()
	_zone_cs.shape = _zone_shape
	zone.add_child(_zone_cs)
	add_child(zone)
	_apply_shapes()

func _apply_shapes() -> void:
	_rim_shape.size = area.size
	_rim_cs.position = area.get_center()
	_zone_shape.size = area.size - Vector2.ONE * edge_margin * 2.0
	_zone_cs.position = area.get_center()

func kill_cause() -> String:
	return "pit" if kind == Kind.PIT else "water"

## Called when something of `radius` skids to a stop at `pos`.
## Returns true if the rim gave way under it.
func try_crumble(pos: Vector2, radius: float) -> bool:
	if not crumbles or kind != Kind.PIT or crumble_count >= max_crumbles:
		return false
	var p := to_local(pos)
	if not area.grow(radius + CRUMBLE_REACH).has_point(p):
		return false
	crumble_count += 1
	# Grow the pit towards whichever side the body is nearest.
	var d_left := absf(p.x - area.position.x)
	var d_right := absf(p.x - area.end.x)
	var d_top := absf(p.y - area.position.y)
	var d_bottom := absf(p.y - area.end.y)
	var m := minf(minf(d_left, d_right), minf(d_top, d_bottom))
	var strip: Rect2
	if m == d_left:
		strip = Rect2(area.position.x - CRUMBLE_STEP, clampf(p.y - 30, area.position.y, area.end.y - 60), CRUMBLE_STEP, 60)
	elif m == d_right:
		strip = Rect2(area.end.x, clampf(p.y - 30, area.position.y, area.end.y - 60), CRUMBLE_STEP, 60)
	elif m == d_top:
		strip = Rect2(clampf(p.x - 30, area.position.x, area.end.x - 60), area.position.y - CRUMBLE_STEP, 60, CRUMBLE_STEP)
	else:
		strip = Rect2(clampf(p.x - 30, area.position.x, area.end.x - 60), area.end.y, 60, CRUMBLE_STEP)
	rubble.append(strip)
	# Physics stays a simple box: grow the whole side. The rubble strip is what you see.
	area = area.merge(strip)
	_apply_shapes.call_deferred()
	Fx.popup(self, pos + Vector2(0, -26), "CRUMBLE", Color(0.85, 0.75, 0.6))
	Fx.ring(self, pos, 30.0, Color(0.7, 0.6, 0.5, 0.9))
	Fx.noise(self, pos, 200.0)
	Fx.shake(self, 6.0)
	queue_redraw()
	return true

func _process(delta: float) -> void:
	if kind == Kind.DEEP_WATER:
		_time += delta
		queue_redraw()

func _draw() -> void:
	var r := area
	if kind == Kind.PIT:
		draw_rect(r, Color(0.01, 0.01, 0.015))
		for i in 4:
			draw_rect(r.grow(-4.0 - i * 6.0), Color(0.16, 0.13, 0.12, 0.35 - i * 0.08), false, 3.0)
		# A pale lip makes the edge readable in the dark.
		draw_rect(r, Color(0.62, 0.55, 0.45), false, 4.0)
		draw_rect(r.grow(5.0), Color(0.62, 0.55, 0.45, 0.25), false, 2.0)
		if crumbles:
			_draw_cracks(r)
		for s in rubble:
			for i in 7:
				var px := s.position.x + fmod(i * 23.7, s.size.x)
				var py := s.position.y + fmod(i * 17.3, s.size.y)
				draw_circle(Vector2(px, py), 2.5, Color(0.35, 0.3, 0.26))
	else:
		draw_rect(r, Color(0.05, 0.13, 0.22))
		draw_rect(r.grow(-edge_margin), Color(0.03, 0.08, 0.15))
		var rows := int(r.size.y / 28.0)
		for row in rows:
			var y := r.position.y + 14.0 + row * 28.0
			var pts := PackedVector2Array()
			var x := r.position.x + 8.0
			while x <= r.end.x - 8.0:
				pts.append(Vector2(x, y + sin(x * 0.05 + _time * 2.0 + row) * 3.0))
				x += 12.0
			if pts.size() >= 2:
				draw_polyline(pts, Color(0.35, 0.55, 0.75, 0.25), 1.5)
		draw_rect(r, Color(0.5, 0.6, 0.65), false, 4.0)
		draw_rect(r.grow(5.0), Color(0.5, 0.6, 0.65, 0.25), false, 2.0)

## Jagged marks along the rim so a crumbling pit looks different from solid stone.
func _draw_cracks(r: Rect2) -> void:
	var c := Color(0.25, 0.2, 0.17)
	var step := 34.0
	var x := r.position.x + 10.0
	while x < r.end.x - 10.0:
		draw_polyline(PackedVector2Array([Vector2(x, r.position.y - 6), Vector2(x + 5, r.position.y - 1), Vector2(x + 2, r.position.y + 3)]), c, 1.5)
		draw_polyline(PackedVector2Array([Vector2(x + 12, r.end.y + 6), Vector2(x + 7, r.end.y + 1), Vector2(x + 10, r.end.y - 3)]), c, 1.5)
		x += step
	var y := r.position.y + 10.0
	while y < r.end.y - 10.0:
		draw_polyline(PackedVector2Array([Vector2(r.position.x - 6, y), Vector2(r.position.x - 1, y + 5), Vector2(r.position.x + 3, y + 2)]), c, 1.5)
		draw_polyline(PackedVector2Array([Vector2(r.end.x + 6, y + 12), Vector2(r.end.x + 1, y + 7), Vector2(r.end.x - 3, y + 10)]), c, 1.5)
		y += step
