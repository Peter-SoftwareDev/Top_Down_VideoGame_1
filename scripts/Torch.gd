@tool
extends Node2D
## A wall torch or a freestanding brazier: a flickering warm light.
##
## Guards see you much further in the light than in the dark. Knock a torch out with
## a bolt or a stun rock to make a patch of darkness. It hisses as it goes out, and
## a guard who comes to look will light it again.

const L = preload("res://scripts/Layers.gd")
const Fx = preload("res://scripts/Fx.gd")

## A freestanding brazier (drawn as a bowl) rather than a wall torch.
@export var brazier: bool = false:
	set(value):
		brazier = value
		queue_redraw()
## How far the light reaches.
@export var light_radius: float = 260.0
@export var lit: bool = true

const DOUSE_NOISE := 200.0

var light: PointLight2D
var _t := 0.0

func _ready() -> void:
	_t = randf() * 10.0
	if Engine.is_editor_hint():
		return
	add_to_group("torch")
	light = PointLight2D.new()
	light.texture = Fx.radial_texture()
	light.texture_scale = light_radius / 128.0
	light.color = Color(1.0, 0.68, 0.38)
	light.shadow_enabled = true
	light.shadow_color = Color(0, 0, 0, 0.85)
	light.enabled = lit
	add_child(light)
	var area := Area2D.new()
	area.collision_layer = L.TORCH
	area.collision_mask = 0
	area.monitoring = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 18.0 if brazier else 11.0   # Bigger than the solid base so shots reach the flame first.
	cs.shape = c
	area.add_child(cs)
	add_child(area)
	if brazier:
		# A brazier is solid and waist-high: low cover you can crouch behind.
		var body := StaticBody2D.new()
		body.collision_layer = L.LOW_WALL
		body.collision_mask = 0
		var bcs := CollisionShape2D.new()
		var bc := CircleShape2D.new()
		bc.radius = 10.0
		bcs.shape = bc
		body.add_child(bcs)
		add_child(body)

func extinguish() -> void:
	if not lit:
		return
	lit = false
	light.enabled = false
	Fx.popup(self, global_position + Vector2(0, -22), "doused", Color(0.7, 0.7, 0.75))
	Fx.ring(self, global_position, 24.0, Color(0.5, 0.5, 0.55, 0.9))
	Fx.noise(self, global_position, DOUSE_NOISE)
	queue_redraw()

func relight() -> void:
	if lit:
		return
	lit = true
	light.enabled = true
	Fx.popup(self, global_position + Vector2(0, -22), "relit", Color(1.0, 0.75, 0.4))
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if light != null and lit:
		light.energy = 0.95 + sin(_t * 13.0) * 0.06 + sin(_t * 7.3) * 0.05
	queue_redraw()

func _draw() -> void:
	var f := 1.0 + sin(_t * 15.0) * 0.15
	if brazier:
		draw_circle(Vector2.ZERO, 13.0, Color(0.18, 0.16, 0.15))
		draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color(0.4, 0.36, 0.32), 2.0)
		if lit:
			draw_circle(Vector2.ZERO, 8.0 * f, Color(1.0, 0.55, 0.2))
			draw_circle(Vector2(0, -1), 4.0 * f, Color(1.0, 0.95, 0.6))
		else:
			draw_circle(Vector2.ZERO, 7.0, Color(0.25, 0.22, 0.2))
			draw_circle(Vector2(2, 1), 1.5, Color(0.6, 0.25, 0.1))
		return
	draw_rect(Rect2(-4, -4, 8, 10), Color(0.3, 0.25, 0.2))
	if lit:
		draw_circle(Vector2(0, -8), 5.0 * f, Color(1.0, 0.6, 0.2))
		draw_circle(Vector2(0, -9), 2.5 * f, Color(1.0, 0.95, 0.6))
	else:
		draw_circle(Vector2(0, -7), 3.5, Color(0.2, 0.18, 0.17))
