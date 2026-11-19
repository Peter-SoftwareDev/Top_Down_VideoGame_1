extends Area2D
## Ammo on the floor: bolts or rocks. Walk over it to pick it up.

const L = preload("res://scripts/Layers.gd")
const PickupMarker = preload("res://scripts/fx/PickupMarker.gd")

@export_enum("bolt", "rock") var kind: String = "bolt"
@export var amount: int = 1

var _t := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = L.PLAYER
	monitorable = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 16.0
	cs.shape = c
	add_child(cs)
	z_index = -1
	add_to_group("pickup")
	_add_marker.call_deferred()

func _add_marker() -> void:
	var m := PickupMarker.new()
	m.target = self
	m.kind = kind
	var layer := get_tree().get_first_node_in_group("fx_layer")
	(layer if layer != null else get_parent()).add_child(m)
	m.global_position = global_position

func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	for body in get_overlapping_bodies():
		if body.has_method("collect") and body.collect(kind, amount):
			queue_free()
			return

func _draw() -> void:
	var glow := 0.35 + sin(_t * 4.0) * 0.15
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 20, Color(1.0, 0.95, 0.7, glow), 1.5)
	for i in mini(amount, 4):
		var off := Vector2(-4.0 + i * 3.0, -2.0 + i * 1.5)
		if kind == "bolt":
			draw_line(off + Vector2(-6, 2), off + Vector2(6, -2), Color(0.85, 0.7, 0.45), 2.0)
		else:
			draw_circle(off, 4.0, Color(0.68, 0.66, 0.6))
