extends CanvasLayer

@onready var health_label: Label = $HealthLabel
@onready var score_label: Label = $ScoreLabel

func _ready() -> void:
	set_stats(5, 0)
	if health_label != null:
		health_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
		health_label.add_theme_font_size_override("font_size", 20)
	if score_label != null:
		score_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
		score_label.add_theme_font_size_override("font_size", 20)

func set_stats(health: int, score: int) -> void:
	if health_label != null:
		health_label.text = "Health: %d" % health
	if score_label != null:
		score_label.text = "Score: %d" % score
