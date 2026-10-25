extends Area2D

@export var speed: float = 500.0
var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	if position.length() > 4000:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		body.take_damage(1)
		queue_free()
	elif body.has_method("take_damage"):
		body.take_damage(1)
		queue_free()
