extends CanvasLayer

@onready var health_label: Label = $HealthLabel
@onready var score_label: Label = $ScoreLabel

func set_stats(health: int, score: int) -> void:
	health_label.text = "Health: %d" % health
	score_label.text = "Score: %d" % score
