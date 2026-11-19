extends RefCounted
## Small helpers for feedback effects: floating text, rings, noise, shake, hit stop, drops.

const FloatText = preload("res://scripts/fx/FloatText.gd")
const Ring = preload("res://scripts/fx/Ring.gd")
const Pickup = preload("res://scripts/Pickup.gd")
const L = preload("res://scripts/Layers.gd")

static func _layer(node: Node) -> Node:
	var layer := node.get_tree().get_first_node_in_group("fx_layer")
	return layer if layer != null else node.get_tree().current_scene

## Text that floats up and fades, e.g. "STUNNED" or "FELL!".
static func popup(node: Node, pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	var f := FloatText.new()
	f.text = text
	f.color = color
	f.position = pos
	_layer(node).add_child(f)

## An expanding circle.
static func ring(node: Node, pos: Vector2, radius: float, color: Color) -> void:
	var r := Ring.new()
	r.max_radius = radius
	r.color = color
	r.position = pos
	_layer(node).add_child(r)

## A sound in the world. Unaware enemies inside the radius come to investigate.
static func noise(node: Node, pos: Vector2, radius: float) -> void:
	ring(node, pos, radius, Color(1.0, 0.9, 0.5, 0.45))
	node.get_tree().call_group("enemy", "hear_noise", pos, radius)

## A guard raising the alarm. Unaware guards in range run to `target`.
static func alarm(node: Node, pos: Vector2, radius: float, target: Vector2) -> void:
	ring(node, pos, radius, Color(1.0, 0.3, 0.25, 0.6))
	node.get_tree().call_group("enemy", "hear_alarm", node, pos, radius, target)

static func shake(node: Node, amount: float) -> void:
	node.get_tree().call_group("player", "add_shake", amount)

## Briefly slow time. Tiny `time_scale` for a split second = hit stop; ~0.3 for longer = slow motion.
static func hitstop(node: Node, duration: float, time_scale: float) -> void:
	node.get_tree().call_group("game", "hitstop", duration, time_scale)

static func in_hazard(node: Node, pos: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pos
	q.collision_mask = L.HAZARD_ZONE
	q.collide_with_areas = true
	q.collide_with_bodies = false
	return not node.get_tree().current_scene.get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()

## Drop ammo on the floor. Anything that lands in a pit or water is lost.
static func drop(node: Node, pos: Vector2, kind: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	if in_hazard(node, pos):
		ring(node, pos, 14.0, Color(0.6, 0.8, 1.0, 0.7))
		return
	var p := Pickup.new()
	p.kind = kind
	p.amount = amount
	p.position = pos
	node.get_tree().current_scene.add_child.call_deferred(p)

## How lit a spot is, 0 (pitch dark) to 1 (right by a flame), from torches and braziers.
## Tall walls cast shadows. The player's own dim sight-light doesn't count.
const AMBIENT_LIGHT := 0.0
static func light_level(node: Node, pos: Vector2) -> float:
	var level := AMBIENT_LIGHT
	var space: PhysicsDirectSpaceState2D = node.get_tree().current_scene.get_world_2d().direct_space_state
	for t in node.get_tree().get_nodes_in_group("torch"):
		if not t.lit:
			continue
		var d: float = t.global_position.distance_to(pos)
		if d >= t.light_radius:
			continue
		var l := 1.0 - pow(d / t.light_radius, 2.0)
		if l <= level:
			continue
		var q := PhysicsRayQueryParameters2D.create(t.global_position, pos, L.WORLD)
		if space.intersect_ray(q).is_empty():
			level = l
	return clampf(level, 0.0, 1.0)

## A soft round texture used for lights.
static func radial_texture(px: int = 256) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = px
	t.height = px
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
