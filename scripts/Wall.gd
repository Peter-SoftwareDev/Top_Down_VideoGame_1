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

## Seen from above at a slight angle: irregular capstones on top, and a strip of brick
## courses on the front face so walls have height.
func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 31.0 + position.y * 17.0 + size.x)
	if low:
		_draw_rubble(r, rng)
		return
	var face_h := minf(12.0, size.y * 0.35) if size.x >= size.y * 0.6 else 0.0
	var top := Rect2(r.position, Vector2(r.size.x, r.size.y - face_h))
	draw_rect(r, Color(0.13, 0.12, 0.15))
	# Capstones: courses along the wall's long axis, blocks of random length.
	var horizontal := top.size.x >= top.size.y
	var across := top.size.y if horizontal else top.size.x
	var along := top.size.x if horizontal else top.size.y
	var courses := maxi(1, int(round(across / 14.0)))
	var course_w := across / courses
	for ci in courses:
		var t := 0.0
		t -= rng.randf_range(0.0, 10.0)
		while t < along:
			var bl := rng.randf_range(14.0, 34.0)
			var a0 := maxf(t, 0.0)
			var a1 := minf(t + bl, along)
			if a1 - a0 > 1.0:
				var block: Rect2
				if horizontal:
					block = Rect2(top.position + Vector2(a0, ci * course_w), Vector2(a1 - a0, course_w))
				else:
					block = Rect2(top.position + Vector2(ci * course_w, a0), Vector2(course_w, a1 - a0))
				block = block.grow(-1.0)
				var shade := rng.randf_range(0.0, 1.0)
				draw_rect(block, Color(0.22, 0.21, 0.25).lerp(Color(0.33, 0.31, 0.35), shade))
				draw_rect(Rect2(block.position, Vector2(block.size.x, 1.0)), Color(0.42, 0.4, 0.44, 0.7))
				draw_rect(Rect2(block.position, Vector2(1.0, block.size.y)), Color(0.38, 0.36, 0.4, 0.5))
				if rng.randf() < 0.18:   # a chipped corner
					draw_rect(Rect2(block.end - Vector2(3, 3), Vector2(3, 3)), Color(0.13, 0.12, 0.15))
			t += bl
	if face_h > 0.0:
		# The front face: smaller brick courses in shadow, darker towards the floor.
		var f := Rect2(Vector2(r.position.x, r.end.y - face_h), Vector2(r.size.x, face_h))
		draw_rect(f, Color(0.17, 0.16, 0.19))
		var rows := maxi(1, int(face_h / 5.0))
		for row in rows:
			var y := f.position.y + row * (face_h / rows)
			var x := f.position.x - (row % 2) * 6.0
			while x < f.end.x:
				var bw := rng.randf_range(9.0, 15.0)
				var b := Rect2(Vector2(maxf(x, f.position.x), y), Vector2(minf(x + bw, f.end.x) - maxf(x, f.position.x), face_h / rows)).grow(-0.5)
				var k := 0.75 - float(row) / rows * 0.4
				draw_rect(b, Color(0.27, 0.25, 0.29) * k)
				x += bw
		draw_rect(Rect2(f.position, Vector2(f.size.x, 1.0)), Color(0.45, 0.43, 0.47))
	draw_rect(r, Color(0.07, 0.06, 0.09), false, 1.5)

## A waist-high barricade of piled rubble.
func _draw_rubble(r: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(r.grow(-1.0), Color(0.18, 0.17, 0.2))
	var n := int(r.size.x * r.size.y / 60.0)
	for i in n:
		var p := r.position + Vector2(rng.randf_range(3.0, r.size.x - 3.0), rng.randf_range(3.0, r.size.y - 3.0))
		var rad := rng.randf_range(3.0, 6.0)
		var shade := rng.randf_range(0.0, 1.0)
		draw_circle(p + Vector2(0, 1), rad, Color(0.1, 0.09, 0.12))
		draw_circle(p, rad, Color(0.3, 0.28, 0.32).lerp(Color(0.44, 0.41, 0.45), shade))
		draw_circle(p - Vector2(rad * 0.3, rad * 0.35), rad * 0.4, Color(0.52, 0.49, 0.53, 0.6))
