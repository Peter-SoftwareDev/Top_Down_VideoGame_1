@tool
extends Node2D
## A wall torch: a flickering warm light.

const Fx = preload("res://scripts/Fx.gd")

var light: PointLight2D
var _t := 0.0

func _ready() -> void:
	_t = randf() * 10.0
	if Engine.is_editor_hint():
		return
	light = PointLight2D.new()
	light.texture = Fx.radial_texture()
	light.texture_scale = 2.2
	light.color = Color(1.0, 0.68, 0.38)
	add_child(light)

func _process(delta: float) -> void:
	_t += delta
	if light != null:
		light.energy = 0.95 + sin(_t * 13.0) * 0.06 + sin(_t * 7.3) * 0.05
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-4, -4, 8, 10), Color(0.3, 0.25, 0.2))
	var f := 1.0 + sin(_t * 15.0) * 0.15
	draw_circle(Vector2(0, -8), 5.0 * f, Color(1.0, 0.6, 0.2))
	draw_circle(Vector2(0, -9), 2.5 * f, Color(1.0, 0.95, 0.6))
