extends RefCounted
## Small helpers for feedback effects: floating text, rings, noise, screen shake.

const FloatText = preload("res://scripts/fx/FloatText.gd")
const Ring = preload("res://scripts/fx/Ring.gd")

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

static func shake(node: Node, amount: float) -> void:
	node.get_tree().call_group("player", "add_shake", amount)

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
