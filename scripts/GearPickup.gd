extends Area2D
## A piece of gear lying on the floor. Walk over it to put it on. Whatever you were
## wearing in that slot drops in its place, so you can always swap back.

const L = preload("res://scripts/Layers.gd")
const Fx = preload("res://scripts/Fx.gd")
const PickupMarker = preload("res://scripts/fx/PickupMarker.gd")

@export_enum("back", "head", "torso", "hands", "feet") var slot: String = "head"
@export var tier: int = 1

const TIER_COLORS := [Color(0.6, 0.6, 0.62), Color(0.62, 0.5, 0.38), Color(0.7, 0.28, 0.25), Color(0.85, 0.65, 0.3)]

## A freshly dropped item waits until you step off it before it can be picked up again.
var armed := true
var _t := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = L.PLAYER
	monitorable = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 14.0
	cs.shape = c
	add_child(cs)
	z_index = -1
	add_to_group("pickup")
	body_exited.connect(func(b): if b.is_in_group("player"): armed = true)
	_add_marker.call_deferred()

var kind: String:
	get: return "gear"

func _add_marker() -> void:
	var m := PickupMarker.new()
	m.target = self
	m.kind = "gear"
	var layer := get_tree().get_first_node_in_group("fx_layer")
	(layer if layer != null else get_parent()).add_child(m)
	m.global_position = global_position

func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not armed:
		return
	for body in get_overlapping_bodies():
		if body.has_method("equip") and not body.is_dead:
			var old: int = body.equip(slot, tier)
			Fx.popup(body, body.global_position + Vector2(0, -44), "+ " + body.GEAR_NAMES[slot][tier], Color(0.75, 0.95, 0.85))
			if old >= 0 and not (slot == "hands" and old == 0):   # Broken shackles are just thrown away.
				var drop: Area2D = (load("res://scripts/GearPickup.gd") as GDScript).new()
				drop.slot = slot
				drop.tier = old
				drop.armed = false
				drop.position = global_position
				get_parent().add_child.call_deferred(drop)
			queue_free()
			return

func _draw() -> void:
	var c: Color = TIER_COLORS[clampi(tier, 0, 3)]
	var glow := 0.35 + sin(_t * 3.0) * 0.15
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, Color(0.7, 1.0, 0.85, glow), 1.5)
	# A bundle: folded cloth/armour with a little icon for the slot.
	draw_rect(Rect2(-7, -4, 14, 9), c.darkened(0.3))
	draw_rect(Rect2(-7, -4, 14, 3), c)
	var icon := {"head": Rect2(-3, -9, 6, 5), "torso": Rect2(-4, -9, 8, 5), "hands": Rect2(-5, -8, 3, 4),
		"feet": Rect2(-5, -7, 4, 3), "back": Rect2(-6, -9, 12, 3)}
	draw_rect(icon[slot], c.lightened(0.2))
	for i in tier:
		draw_rect(Rect2(-6 + i * 4, 6, 3, 2), Color(1.0, 0.9, 0.6))
