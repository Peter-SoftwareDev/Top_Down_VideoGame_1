extends Node2D

var max_radius := 40.0
var color := Color.WHITE
var life := 0.6
var age := 0.0

func _ready() -> void:
	z_index = 90

func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k := clampf(age / life, 0.0, 1.0)
	var c := color
	c.a *= 1.0 - k
	draw_arc(Vector2.ZERO, max_radius * (0.2 + 0.8 * k), 0.0, TAU, 48, c, 2.0)
