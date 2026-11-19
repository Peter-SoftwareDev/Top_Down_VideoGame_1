extends Node2D

var text := ""
var color := Color.WHITE
var life := 0.9
var age := 0.0

func _ready() -> void:
	z_index = 100

func _process(delta: float) -> void:
	age += delta
	position.y -= 28.0 * delta
	modulate.a = clampf(1.0 - age / life, 0.0, 1.0)
	if age >= life:
		queue_free()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var font_size := 15
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(-w * 0.5, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
