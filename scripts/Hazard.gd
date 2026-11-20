@tool
extends Node2D
## A pit or a pool of deep water.
##
## Anything walking is stopped by its rim. Anything knocked back slides over the rim,
## and once its centre is past `edge_margin` it falls in (or drowns).
##
## Two styles:
##   COLLAPSED   floor that broke and fell into the Drop: an irregular, jagged outline with
##               hanging slabs and rubble. Can crumble (`crumbles`): a body that skids to a stop
##               on the edge breaks away a new lobe of floor. Collision follows the outline exactly.
##   CONSTRUCTED shafts and basins built on purpose (oubliettes, the pits a bridge spans, cisterns):
##               straight edges, a dressed-stone kerb, a visible shaft wall. Never crumbles.
## Water is always a built basin, drawn with an animated pixel-art shader.

const L = preload("res://scripts/Layers.gd")
const Fx = preload("res://scripts/Fx.gd")
const WATER_SHADER = preload("res://shaders/water.gdshader")

enum Kind { PIT, DEEP_WATER }
enum Style { COLLAPSED, CONSTRUCTED }

@export var kind: Kind = Kind.PIT:
	set(value):
		kind = value
		queue_redraw()
@export var style: Style = Style.COLLAPSED:
	set(value):
		style = value
		outline = PackedVector2Array()
		queue_redraw()
@export var size: Vector2 = Vector2(200, 120):
	set(value):
		size = value
		area = Rect2(-size * 0.5, size)
		outline = PackedVector2Array()
		queue_redraw()
## How far past the rim a centre must go before it falls in.
@export var edge_margin: float = 10.0
## Collapsed pits only: the edge breaks under anything that skids to a stop on it.
@export var crumbles: bool = false:
	set(value):
		crumbles = value
		queue_redraw()
## How many times the rim can crumble before it's solid rock.
@export var max_crumbles: int = 4
## Collapsed pits only: how sharp and broken the edge is, in pixels.
@export var jaggedness: float = 3.0

const CRUMBLE_REACH := 10.0   # A stop this close outside the rim still crumbles it.
const CRUMBLE_STEP := 26.0    # How far a crumble bites into the floor.
const KERB := 6.0             # Width of the dressed-stone kerb around built pits and basins.

var area := Rect2(-100, -60, 200, 120)
var crumble_count := 0
var outline := PackedVector2Array()
var _bulges: Array = []        # [{angle, amount}] added by crumbling
var _noise: FastNoiseLite
var _rim_poly: CollisionPolygon2D
var _zone_poly: CollisionPolygon2D
var _water: ColorRect

func _ready() -> void:
	area = Rect2(-size * 0.5, size)
	if kind == Kind.DEEP_WATER:
		_make_water()
	if Engine.is_editor_hint():
		return
	add_to_group("hazard")
	var rim := StaticBody2D.new()
	rim.collision_layer = L.HAZARD_EDGE
	rim.collision_mask = 0
	_rim_poly = CollisionPolygon2D.new()
	rim.add_child(_rim_poly)
	add_child(rim)
	var zone := Area2D.new()
	zone.collision_layer = L.HAZARD_ZONE
	zone.collision_mask = 0
	zone.monitoring = false
	_zone_poly = CollisionPolygon2D.new()
	zone.add_child(_zone_poly)
	add_child(zone)
	_apply_shapes()

func is_collapsed() -> bool:
	return kind == Kind.PIT and style == Style.COLLAPSED

func kill_cause() -> String:
	return "pit" if kind == Kind.PIT else "water"

# --- Shape --------------------------------------------------------------------------------
func _make_noise() -> void:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = int(position.x * 7.0 + position.y * 13.0)
		_noise.frequency = 0.02
		_noise.fractal_octaves = 3

## The collapsed outline, walked around the centre: a squarish base shape (so the hole still
## fills its area), big irregular lobes from noise, sharp per-stone jags, plus any crumbles.
func _make_collapsed_outline() -> PackedVector2Array:
	_make_noise()
	var c := area.get_center()
	var a := area.size.x * 0.5
	var b := area.size.y * 0.5
	var n := clampi(int((a + b) * PI / 4.0), 48, 420)
	var pts := PackedVector2Array()
	for i in n:
		var th := TAU * float(i) / n
		var ct := cos(th)
		var s := sin(th)
		var base := pow(pow(absf(ct) / a, 4.0) + pow(absf(s) / b, 4.0), -0.25)
		var lobe := _noise.get_noise_2d(ct * 90.0, s * 90.0)
		var r := base * (0.9 + 0.22 * lobe)
		var jag := fmod(float(i * 7919 % 97) * 0.618, 1.0) - 0.5
		r += jag * jaggedness * 2.0
		for bulge in _bulges:
			var d := angle_difference(th, bulge.angle)
			r += bulge.amount * exp(-pow(d / 0.3, 2.0))
		pts.append(c + Vector2(ct, s) * r)
	return pts

func _rect_outline() -> PackedVector2Array:
	return PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])

func _apply_shapes() -> void:
	outline = _make_collapsed_outline() if is_collapsed() else _rect_outline()
	if _rim_poly != null:
		_rim_poly.polygon = outline
		var inset := Geometry2D.offset_polygon(outline, -edge_margin)
		_zone_poly.polygon = inset[0] if inset.size() > 0 else outline
	queue_redraw()

func _get_outline() -> PackedVector2Array:
	if outline.size() < 3:
		outline = _make_collapsed_outline() if is_collapsed() else _rect_outline()
	return outline

## Called when something of `radius` skids to a stop at `pos`.
## Returns true if the edge gave way under it.
func try_crumble(pos: Vector2, radius: float) -> bool:
	if not crumbles or not is_collapsed() or crumble_count >= max_crumbles:
		return false
	var p := to_local(pos)
	var grown := Geometry2D.offset_polygon(_get_outline(), radius + CRUMBLE_REACH)
	if grown.is_empty() or not Geometry2D.is_point_in_polygon(p, grown[0]):
		return false
	crumble_count += 1
	_bulges.append({"angle": (p - area.get_center()).angle(), "amount": CRUMBLE_STEP})
	_apply_shapes.call_deferred()
	Fx.popup(self, pos + Vector2(0, -26), "CRUMBLE", Color(0.85, 0.75, 0.6))
	Fx.ring(self, pos, 30.0, Color(0.7, 0.6, 0.5, 0.9))
	Fx.noise(self, pos, 200.0)
	Fx.shake(self, 6.0)
	return true

# --- Water ----------------------------------------------------------------------------------
func _make_water() -> void:
	if _water != null:
		return
	_water = ColorRect.new()
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water.position = area.position
	_water.size = area.size
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("rect_size", area.size)
	mat.set_shader_parameter("seed", fmod(position.x * 0.13 + position.y * 0.07, 50.0))
	_water.material = mat
	add_child(_water)

# --- Drawing --------------------------------------------------------------------------------
func _draw() -> void:
	if kind == Kind.DEEP_WATER:
		_draw_kerb(area)
	elif is_collapsed():
		_draw_collapsed()
	else:
		_draw_shaft()

## Dressed coping stones around a built pit or basin.
func _draw_kerb(r: Rect2) -> void:
	var outer := r.grow(KERB)
	draw_rect(outer, Color(0.1, 0.09, 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 11.0 + position.y * 3.0)
	# Top and bottom runs, then the sides.
	for side in 4:
		var horizontal := side < 2
		var start := outer.position + (Vector2(0, outer.size.y - KERB) if side == 1 else Vector2.ZERO)
		if side == 3:
			start = outer.position + Vector2(outer.size.x - KERB, 0)
		var length := outer.size.x if horizontal else outer.size.y
		var t := 0.0
		while t < length:
			var sl := rng.randf_range(16.0, 30.0)
			var seg := minf(sl, length - t)
			var stone := Rect2(start + (Vector2(t, 0) if horizontal else Vector2(0, t)), Vector2(seg, KERB) if horizontal else Vector2(KERB, seg)).grow(-0.5)
			var shade := rng.randf_range(0.0, 1.0)
			draw_rect(stone, Color(0.33, 0.31, 0.34).lerp(Color(0.42, 0.4, 0.43), shade))
			draw_rect(Rect2(stone.position, Vector2(stone.size.x, 1.0)), Color(0.55, 0.52, 0.55, 0.8))
			draw_rect(Rect2(stone.position + Vector2(0, stone.size.y - 1.0), Vector2(stone.size.x, 1.0)), Color(0.18, 0.17, 0.2))
			t += sl

## A shaft built into the floor: kerb, then the far wall going down into darkness.
func _draw_shaft() -> void:
	var r := area
	_draw_kerb(r)
	draw_rect(r, Color(0.01, 0.01, 0.015))
	# The far (top) wall of the shaft is visible from this angle: brick courses fading into the dark.
	var wall_h := minf(r.size.y * 0.3, 26.0)
	var rows := int(wall_h / 5.0)
	for row in rows:
		var y := r.position.y + row * 5.0
		var fade := 1.0 - float(row) / rows
		var x := r.position.x - (row % 2) * 6.0
		while x < r.end.x:
			var bw := 12.0
			var b := Rect2(Vector2(maxf(x, r.position.x), y), Vector2(minf(x + bw, r.end.x) - maxf(x, r.position.x), 5.0)).grow(-0.5)
			draw_rect(b, Color(0.22, 0.2, 0.24) * fade)
			x += bw
	# Side walls: thin dark slivers.
	draw_rect(Rect2(r.position, Vector2(3.0, r.size.y)), Color(0.07, 0.06, 0.08))
	draw_rect(Rect2(Vector2(r.end.x - 3.0, r.position.y), Vector2(3.0, r.size.y)), Color(0.05, 0.04, 0.06))

## Floor that broke away: a jagged hole with slabs hanging over the edge, rubble and cracks.
func _draw_collapsed() -> void:
	var poly := _get_outline()
	var c := area.get_center()
	draw_colored_polygon(poly, Color(0.01, 0.01, 0.015))
	# Broken slabs still clinging to the rim, tilting into the hole: short runs of the edge,
	# each pushed a few pixels inwards towards the centre.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 5.0 + position.y * 9.0)
	var si := 0
	while si < poly.size() - 1:
		var j := mini(si + rng.randi_range(2, 5), poly.size() - 1)
		if rng.randf() < 0.5:
			var a0 := poly[si]
			var a1 := poly[j]
			var depth := rng.randf_range(4.0, 9.0)
			var k0 := a0 + (c - a0).normalized() * depth
			var k1 := a1 + (c - a1).normalized() * depth
			var lit := 0.5 + 0.5 * (a0 - c).normalized().dot(Vector2(-0.6, -0.8))
			var sc := Color(0.14, 0.12, 0.15).lerp(Color(0.27, 0.24, 0.26), lit)
			draw_primitive(PackedVector2Array([a0, a1, k1, k0]), PackedColorArray([sc, sc, sc.darkened(0.4), sc.darkened(0.4)]), PackedVector2Array())
		si = j + 1
	for d in 4:
		var bands := Geometry2D.offset_polygon(poly, -(9.0 + d * 8.0))
		for band in bands:
			var closed := band.duplicate()
			closed.append(band[0])
			draw_polyline(closed, Color(0.12, 0.1, 0.11, 0.35 - d * 0.08), 3.0)
	# The broken lip: brighter where it faces the light (upper left), darker where it turns away.
	for i in poly.size():
		var a0 := poly[i]
		var a1 := poly[(i + 1) % poly.size()]
		var lit := 0.5 + 0.5 * (a0 - c).normalized().dot(Vector2(-0.6, -0.8))
		draw_line(a0, a1, Color(0.3, 0.27, 0.27).lerp(Color(0.62, 0.56, 0.5), lit), 2.0)
	# Rubble: little broken chunks on the floor around the hole.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = int(position.x * 3.0 + position.y * 5.0)
	for i in range(0, poly.size(), 2):
		if rng2.randf() < 0.4:
			var out := (poly[i] - c).normalized()
			var p := poly[i] + out * rng2.randf_range(3.0, 12.0)
			var s := rng2.randf_range(1.5, 3.2)
			var chunk := PackedVector2Array([p + Vector2(-s, -s * 0.6), p + Vector2(s * 0.8, -s), p + Vector2(s, s * 0.5), p + Vector2(-s * 0.4, s)])
			var cc := Color(0.3, 0.27, 0.29)
			draw_primitive(chunk, PackedColorArray([cc, cc, cc, cc]), PackedVector2Array())
			draw_line(chunk[0], chunk[1], Color(0.48, 0.45, 0.46), 1.0)
	# Cracks running out into the floor (more of them if the edge is still crumbling).
	var every := 5 if crumbles else 11
	for i in range(0, poly.size(), every):
		var p := poly[i]
		var out := (p - c).normalized()
		var side := out.orthogonal() * (2.5 if i % 2 == 0 else -2.5)
		var length := rng2.randf_range(8.0, 18.0) * (1.4 if crumbles else 1.0)
		draw_polyline(PackedVector2Array([p, p + out * length * 0.4 + side, p + out * length * 0.75 - side * 0.5, p + out * length]), Color(0.12, 0.1, 0.11), 1.0)
