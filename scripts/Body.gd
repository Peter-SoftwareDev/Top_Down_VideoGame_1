extends CharacterBody2D
## A dead guard. Left where it fell, it's evidence: an unaware guard who sees it raises the
## alarm. You can kick it (or hit it with a rock) to slide it into a pit or deep water, where
## it's never found. Darkness hides bodies too: guards spot them from much closer in shadow.

const L = preload("res://scripts/Layers.gd")
const Fx = preload("res://scripts/Fx.gd")
const CharacterSprite = preload("res://scripts/CharacterSprite.gd")

## Sprite settings copied from the guard who died.
var look := {}
## Heavier bodies (the Gaoler) slide less.
var weight := 1.0
var radius := 14.0
var discovered := false
var light := 0.0
var knock_velocity := Vector2.ZERO
var sinking := false
var feet: Area2D

func _ready() -> void:
	add_to_group("body")
	add_to_group("pushable")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 0                       # People walk over bodies.
	collision_mask = L.WORLD | L.LOW_WALL | L.HAZARD_EDGE
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 9.0
	cs.shape = c
	add_child(cs)
	feet = Area2D.new()
	feet.collision_layer = 0
	feet.collision_mask = L.HAZARD_ZONE
	feet.monitorable = false
	var fcs := CollisionShape2D.new()
	var fc := CircleShape2D.new()
	fc.radius = 3.0
	fcs.shape = fc
	feet.add_child(fcs)
	add_child(feet)
	var s := CharacterSprite.new()
	for k in look:
		s.set(k, look[k])
	add_child(s)
	s.set_lying(true)
	s.set_tint(Color(0.7, 0.62, 0.62))
	z_index = -1
	_update_light.call_deferred()

func _update_light() -> void:
	light = Fx.light_level(self, global_position)

func is_dying() -> bool:
	return sinking

func take_damage(_amount: int, _cause: String, _allow_sneak: bool = true) -> void:
	pass

func apply_knockback(impulse: Vector2, _stun: float, _impact: bool = false) -> void:
	if sinking:
		return
	knock_velocity = impulse * 0.9 * weight
	set_deferred("collision_mask", L.WORLD | L.LOW_WALL)   # Slides over pit rims.

func _physics_process(delta: float) -> void:
	if sinking or knock_velocity.length() < 20.0:
		return
	velocity = knock_velocity
	move_and_slide()
	knock_velocity = velocity.move_toward(Vector2.ZERO, 1300.0 * delta)
	for area in feet.get_overlapping_areas():
		var h = area.get_parent()
		if h != null and h.is_in_group("hazard"):
			_sink(h.kill_cause())
			return
	if knock_velocity.length() < 20.0:
		knock_velocity = Vector2.ZERO
		set_deferred("collision_mask", L.WORLD | L.LOW_WALL | L.HAZARD_EDGE)
		_update_light()

func _sink(cause: String) -> void:
	sinking = true
	remove_from_group("body")
	Fx.popup(self, global_position + Vector2(0, -20), "HIDDEN" if not discovered else "GONE", Color(0.7, 0.8, 0.9))
	if cause == "water":
		Fx.ring(self, global_position, 30.0, Color(0.6, 0.8, 1.0, 0.9))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.2, 0.2), 0.5)
	tw.tween_property(self, "modulate", Color(0.2, 0.2, 0.3, 0.0), 0.5)
	tw.chain().tween_callback(queue_free)

func _draw() -> void:
	# A dark stain under the body.
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 13.0, Color(0.25, 0.04, 0.05, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
