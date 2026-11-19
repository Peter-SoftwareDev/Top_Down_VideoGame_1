@tool
extends CharacterBody2D
## A heavy crate. Blocks sight, can be kicked or hit by a rock, and slides.
## A crate sliding fast crushes guards it hits; it breaks after two hard impacts
## (or two weapon hits), making a loud noise and spilling its contents.

const L = preload("res://scripts/Layers.gd")
const Fx = preload("res://scripts/Fx.gd")

## What's inside. Spills out when the crate breaks.
@export_enum("nothing", "bolt", "rock") var contents: String = "nothing"
@export var contents_amount: int = 2

const HALF := 15.0
const RADIUS := 15.0
const WEIGHT := 0.85            # Crates slide a bit less far than guards.
const FRICTION := 1300.0
const STOP_SPEED := 30.0
const CRUSH_SPEED := 240.0      # Hitting a guard faster than this hurts it.
const HEAVY_CRUSH_SPEED := 420.0
const BREAK_SPEED := 300.0      # Impacts faster than this damage the crate.
const NOISE_RADIUS := 230.0

var durability := 2
var broken := false
var knock_velocity := Vector2.ZERO
var knock_hits: Array = []
var hit_flash := 0.0
var feet: Area2D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("pushable")
	add_to_group("crate")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = L.PROP
	collision_mask = L.PROP_REST_MASK
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2.ONE * HALF * 2.0
	cs.shape = rect
	add_child(cs)
	feet = Area2D.new()
	feet.collision_layer = 0
	feet.collision_mask = L.HAZARD_ZONE
	feet.monitorable = false
	var fcs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 3.0
	fcs.shape = c
	feet.add_child(fcs)
	add_child(feet)

func is_dying() -> bool:
	return broken

func apply_knockback(impulse: Vector2, _stun: float) -> void:
	if broken:
		return
	if knock_velocity.length() < STOP_SPEED:
		knock_hits.clear()
	knock_velocity = impulse * WEIGHT
	set_deferred("collision_mask", L.PROP_KNOCK_MASK)

func take_damage(amount: int, _cause: String, _allow_sneak: bool = true) -> void:
	if broken:
		return
	hit_flash = 0.1
	durability -= amount
	if durability <= 0:
		_break()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or broken:
		return
	hit_flash = maxf(hit_flash - delta, 0.0)
	if knock_velocity.length() < STOP_SPEED:
		queue_redraw()
		return
	var speed_before := knock_velocity.length()
	velocity = knock_velocity
	move_and_slide()
	var impact := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other = col.get_collider()
		if other is Node and other.has_method("apply_knockback"):
			if knock_hits.has(other) or other.is_dying():
				continue
			knock_hits.append(other)
			if other.is_in_group("enemy") and speed_before >= CRUSH_SPEED:
				other.take_damage(2 if speed_before >= HEAVY_CRUSH_SPEED else 1, "crate", false)
				Fx.popup(other, other.global_position + Vector2(0, -28), "CRUSH", Color(1.0, 0.55, 0.3))
				Fx.hitstop(self, 0.07, 0.05)
			other.apply_knockback(knock_velocity * 0.8, 0.5)
			if "knock_hits" in other:
				other.knock_hits.append(self)
			knock_velocity *= 0.3
			impact = true
		elif other is StaticBody2D and speed_before >= BREAK_SPEED:
			knock_velocity = knock_velocity.bounce(col.get_normal()) * 0.2
			impact = true
	if impact and speed_before >= BREAK_SPEED:
		take_damage(1, "impact")
		if broken:
			return
	if not impact:
		knock_velocity = velocity
	knock_velocity = knock_velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	for area in feet.get_overlapping_areas():
		var hazard = area.get_parent()
		if hazard != null and hazard.is_in_group("hazard"):
			_sink(hazard.kill_cause())
			return
	if knock_velocity.length() < STOP_SPEED:
		knock_velocity = Vector2.ZERO
		set_deferred("collision_mask", L.PROP_REST_MASK)
		for h in get_tree().get_nodes_in_group("hazard"):
			if h.try_crumble(global_position, RADIUS):
				_sink("pit")
				return
	queue_redraw()

func _disable() -> void:
	broken = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	feet.set_deferred("monitoring", false)

func _sink(cause: String) -> void:
	_disable()
	if cause == "water":
		Fx.ring(self, global_position, 30.0, Color(0.6, 0.8, 1.0, 0.9))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.2, 0.2), 0.5)
	tw.tween_property(self, "modulate", Color(0.2, 0.2, 0.3, 0.0), 0.5)
	tw.chain().tween_callback(queue_free)

func _break() -> void:
	_disable()
	Fx.popup(self, global_position + Vector2(0, -24), "CRASH", Color(0.9, 0.75, 0.5))
	Fx.ring(self, global_position, 26.0, Color(0.75, 0.55, 0.35, 0.9))
	Fx.noise(self, global_position, NOISE_RADIUS)
	Fx.shake(self, 3.0)
	if contents != "nothing":
		Fx.drop(self, global_position, contents, contents_amount)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.25)
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.25)
	tw.chain().tween_callback(queue_free)

func _draw() -> void:
	var r := Rect2(-Vector2.ONE * HALF, Vector2.ONE * HALF * 2.0)
	var wood := Color(0.48, 0.34, 0.2) if hit_flash <= 0.0 else Color.WHITE
	draw_rect(r.grow(2.0), Color(0, 0, 0, 0.35))
	draw_rect(r, wood)
	var dark := Color(0.3, 0.2, 0.12)
	draw_rect(r, dark, false, 2.0)
	draw_line(r.position, r.end, dark, 2.0)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), dark, 2.0)
	if durability < 2:
		draw_line(Vector2(-8, -12), Vector2(-2, 2), Color(0.12, 0.08, 0.05), 1.5)
	if contents != "nothing":
		draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.9, 0.6, 0.6))
